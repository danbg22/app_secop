import { randomUUID } from 'node:crypto';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { defineBoolean, defineSecret, defineString } from 'firebase-functions/params';
import { onCall, onRequest, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import {
  PRECIOS_CENTAVOS, ROLES_GRATUITOS, esPlanPago, sha256,
  vencimientoPrueba, sumarMesColombia, validarTransaccion, firmaEventoValida,
} from './planes.mjs';

import { huellaCedula, registrarIntentoCedula, vincularCedula } from './identidad.mjs';
import { renovaciones } from './renovaciones.mjs';

initializeApp();
const db = getFirestore();
const auth = getAuth();
const integridad = defineSecret('WOMPI_INTEGRITY_SECRET');
const privada = defineSecret('WOMPI_PRIVATE_KEY');
const eventos = defineSecret('WOMPI_EVENTS_SECRET');
const publica = defineString('WOMPI_PUBLIC_KEY');
const lanzamiento = defineString('PLANES_INICIO_PRUEBA');
const retornoPorDefecto = 'https://contratalegal.com/';
const retorno = defineString('PLANES_RETORNO', { default: retornoPorDefecto });
const opciones = { region: 'us-central1', timeoutSeconds: 60 };
// App Check: se enciende con EXIGIR_APP_CHECK=true en functions/.env.secop-ia
// solo después de exigirlo en la consola y registrar el dominio en
// reCAPTCHA; antes, rechazaría a todos los usuarios.
const exigirAppCheck = defineBoolean('EXIGIR_APP_CHECK', { default: false });
function verificarApp(request) {
  if (exigirAppCheck.value() && !request.app) {
    throw new HttpsError('failed-precondition', 'Actualiza la página e inténtalo de nuevo.');
  }
}
const adminCorreos = [
  'danielbg2231@gmail.com', 'ivanbolano19@gmail.com', 'ibolano@sena.edu.co',
];
const accesos = db.collection('accesos_planes');
const usuarios = db.collection('usuarios');
const intentos = db.collection('intentos_pago_planes');
const pagos = db.collection('pagos_wompi');
const milisegundos = (valor) => valor?.toMillis() ?? 0;
const correoNormal = (valor) => (valor ?? '').trim().toLowerCase();

function wompi() {
  const llave = publica.value().trim();
  if (!/^pub_(test|prod)_/.test(llave)) {
    throw new HttpsError('failed-precondition', 'El comercio de Wompi no está configurado.');
  }
  const sandbox = llave.startsWith('pub_test_');
  return { llave, ambiente: sandbox ? 'test' : 'prod', host: sandbox ? 'sandbox' : 'production' };
}

// La renovación automática viene activada: quien no quiera seguir cancela al
// menos 24 horas antes del siguiente cobro (ver cancelaAntesDelCorte).
const habilitarRenovacion = defineBoolean('WOMPI_RENOVACION_ACTIVA', { default: true });
const cobros = renovaciones({
  db, wompi, privada, integridad,
  disponible: () => habilitarRenovacion.value(),
  retorno: () => retorno.value().trim() || retornoPorDefecto,
  endpoint: () => `https://us-central1-${process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || 'secop-ia'}.cloudfunctions.net/checkoutRenovacion`,
});

async function transaccionWompi(id) {
  if (typeof id !== 'string' || !/^[a-z0-9-]{6,100}$/i.test(id)) {
    throw new HttpsError('invalid-argument', 'El identificador de Wompi no es válido.');
  }
  const { host, ambiente } = wompi();
  const llave = privada.value();
  if (!llave.startsWith(`prv_${ambiente}_`)) {
    throw new HttpsError('failed-precondition', 'La llave privada de Wompi no coincide con el ambiente.');
  }
  const respuesta = await fetch(`https://${host}.wompi.co/v1/transactions/${encodeURIComponent(id)}`, {
    headers: { Authorization: `Bearer ${llave}` },
    signal: AbortSignal.timeout(10000),
  });
  if (respuesta.status === 404) return null;
  if (!respuesta.ok) throw new HttpsError('unavailable', 'No pudimos consultar el pago en Wompi.');
  const { data } = await respuesta.json();
  return data?.id === id ? data : null;
}

async function rolesHistoricos(uid, correo, perfil) {
  if (!correo) return [];
  const documentos = await pagos.where('uid', '==', uid).get();
  const candidatos = new Map(documentos.docs.map((doc) => [doc.id, doc.data()]));
  const ultimo = perfil.ultimoPagoWompi;
  if (typeof ultimo?.transactionId === 'string' && !candidatos.has(ultimo.transactionId)) {
    candidatos.set(ultimo.transactionId, ultimo);
  }
  const roles = await Promise.all([...candidatos].map(async ([id, { rolId, reference }]) => {
    if (!esPlanPago(rolId) || typeof reference !== 'string' ||
        !reference.startsWith(`CL-WOMPI-${rolId.toUpperCase()}-`)) return null;
    if (!/^[a-z0-9-]{6,100}$/i.test(id)) return null;
    const pago = await transaccionWompi(id);
    return validarTransaccion(pago, reference, correo, PRECIOS_CENTAVOS[rolId]) ? rolId : null;
  }));
  return [...new Set(roles.filter(Boolean))];
}

async function cuentaAdministradora(uid) {
  const ref = accesos.doc(uid);
  return db.runTransaction(async (tx) => {
    const existente = await tx.get(ref);
    if (existente.exists) {
      const cuenta = existente.data();
      const accesoAdmin = { admin: true, pruebaRol: null, pruebaHasta: null };
      if (cuenta.admin !== true || cuenta.pruebaRol != null || cuenta.pruebaHasta != null) {
        tx.update(ref, accesoAdmin);
      }
      return { ...cuenta, ...accesoAdmin };
    }
    const cuenta = {
      rolInicial: 'persona', pruebaRol: null, pruebaHasta: null,
      pagadosHasta: {}, historicos: [], admin: true,
    };
    tx.create(ref, cuenta);
    return cuenta;
  });
}

async function obtenerCuenta(uid, perfil) {
  const ref = accesos.doc(uid);
  const existente = await ref.get();
  if (existente.exists) return existente.data();
  const usuario = await auth.getUser(uid);
  const correo = correoNormal(usuario.email);
  if (adminCorreos.includes(correo)) {
    return usuario.emailVerified ? cuentaAdministradora(uid) : null;
  }
  if (perfil.cedulaVinculada !== true) return null;
  const inicio = Date.parse(lanzamiento.value());
  if (!Number.isFinite(inicio)) {
    throw new HttpsError('failed-precondition', 'Falta configurar el inicio de las pruebas.');
  }
  const creacion = Date.parse(usuario.metadata.creationTime);
  const conProveedor = usuario.providerData.some((p) =>
    p.providerId === 'google.com' || p.providerId === 'apple.com');
  const rol = perfil.rolInicialRegistro ?? perfil.rolSolicitadoRegistro ??
    (conProveedor ? 'persona' : '');
  if (!rol && creacion >= inicio) return null;

  const historicos = creacion < inicio || perfil.pagoWompiActivo === true
    ? await rolesHistoricos(uid, correo, perfil) : [];
  const hasta = esPlanPago(rol) && historicos.length === 0
    ? vencimientoPrueba(creacion, inicio) : null;
  const reclamos = [];
  if (hasta && correo) {
    reclamos.push(db.collection('identidades_prueba').doc(sha256(`correo:${correo}`)));
    const documento = perfil.documentoNormalizado ?? '';
    if (perfil.cedulaVinculada !== true || !/^\d{5,20}$/.test(documento)) return null;
    const indice = await db.collection('indices_unicidad').doc(huellaCedula(documento)).get();
    if (indice.data()?.uid !== uid || indice.data()?.tipo !== 'doc') return null;
    reclamos.push(db.collection('identidades_prueba').doc(sha256(`documento:${documento}`)));
  }

  return db.runTransaction(async (tx) => {
    const cuenta = await tx.get(ref);
    if (cuenta.exists) return cuenta.data();
    const usados = reclamos.length ? await tx.getAll(...reclamos) : [];
    const habilitar = hasta && reclamos.length > 0 &&
      usados.every((doc) => !doc.exists || doc.data().uid === uid);
    const data = {
      rolInicial: esPlanPago(rol) || ROLES_GRATUITOS.includes(rol) ? rol : 'persona',
      pruebaRol: habilitar ? rol : null,
      pruebaHasta: habilitar ? Timestamp.fromMillis(hasta) : null,
      pagadosHasta: {},
      historicos,
      admin: false,
    };
    tx.create(ref, data);
    if (habilitar) {
      for (const [i, doc] of usados.entries()) {
        if (!doc.exists) tx.create(reclamos[i], { uid });
      }
    }
    return data;
  });
}

function rolVigente(cuenta, rol, ahora) {
  return cuenta?.admin === true || cuenta?.historicos?.includes(rol) ||
    milisegundos(cuenta?.pagadosHasta?.[rol]) > ahora ||
    (cuenta?.pruebaRol === rol && milisegundos(cuenta?.pruebaHasta) > ahora);
}

async function estado(uid, token, perfil, cuenta) {
  const correo = correoNormal(token.email);
  if (cuenta?.admin === true) {
    await accesos.doc(uid).update({ admin: false });
  }
  let equipo;
  if (token.email_verified === true && correo) {
    const miembro = (await db.collection('miembros_equipo').doc(correo).get()).data();
    if (miembro?.estado === 'activo' && miembro.masterUid !== uid &&
        milisegundos(miembro.vigenteHasta) > Date.now()) {
      const master = miembro.masterUid;
      const pagador = await obtenerCuenta(master, (await usuarios.doc(master).get()).data() ?? {})
        .catch((error) => {
          if (error.code === 'auth/user-not-found') return null;
          throw error;
        });
      if (rolVigente(pagador, 'equipo_juridico', Date.now())) {
        const vencimientos = [
          milisegundos(miembro.vigenteHasta),
          vigenciaEquipo(pagador),
        ];
        equipo = Math.min(...vencimientos);
      }
    }
  }
  const ahora = Date.now();
  const roles = Object.keys(PRECIOS_CENTAVOS).filter((rol) =>
    rolVigente({ ...cuenta, admin: false }, rol, ahora));
  const tienePlanPropio = roles.length > 0;
  if (equipo > ahora && !roles.includes('equipo_juridico')) roles.push('equipo_juridico');
  const pruebaHasta = milisegundos(cuenta?.pruebaHasta);
  const solicitado = perfil.rolSolicitadoRegistro;
  const rolInicial = cuenta?.rolInicial ??
    (esPlanPago(solicitado) || ROLES_GRATUITOS.includes(solicitado) ? solicitado : 'persona');
  const gratis = tienePlanPropio || ROLES_GRATUITOS.includes(rolInicial)
    ? ROLES_GRATUITOS.filter((rol) => Array.isArray(perfil.rolesActivos) && perfil.rolesActivos.includes(rol))
    : [];
  return {
    ahora,
    roles: [...roles, ...gratis],
    preparando: !cuenta && roles.length === 0 && gratis.length === 0,
    rolInicial,
    pruebaRol: cuenta?.pruebaRol,
    pruebaHasta,
    terminoPrueba: pruebaHasta > 0 && pruebaHasta <= ahora,
    graciaEquipoHasta: equipo ?? 0,
    pagadosHasta: Object.fromEntries(Object.entries(cuenta?.pagadosHasta ?? {})
      .map(([rol, fecha]) => [rol, milisegundos(fecha)])),
    historicos: cuenta?.historicos ?? [],
    esAdmin: false,
  };
}

function vigenciaEquipo(cuenta) {
  if (cuenta.admin || cuenta.historicos?.includes('equipo_juridico')) return Infinity;
  return Math.max(
    milisegundos(cuenta.pagadosHasta?.equipo_juridico),
    cuenta.pruebaRol === 'equipo_juridico' ? milisegundos(cuenta.pruebaHasta) : 0,
  );
}

async function iniciarPago(uid, correo, rol, cuenta) {
  if (!esPlanPago(rol) || !correo || !cuenta) {
    throw new HttpsError('failed-precondition', 'Completa primero el registro del plan.');
  }
  if (cuenta.historicos?.includes(rol) || milisegundos(cuenta.pagadosHasta?.[rol]) > Date.now()) {
    throw new HttpsError('already-exists', 'Ya tienes una suscripción vigente para este plan.');
  }
  const { llave, ambiente } = wompi();
  const secreto = integridad.value();
  if (!secreto.startsWith(`${ambiente}_integrity_`)) {
    throw new HttpsError('failed-precondition', 'La firma de Wompi no coincide con el ambiente.');
  }
  if (!privada.value().startsWith(`prv_${ambiente}_`)) {
    throw new HttpsError('failed-precondition', 'La llave privada de Wompi no coincide con el ambiente.');
  }
  let volver;
  try {
    volver = new URL(retorno.value().trim() || retornoPorDefecto);
  } catch {
    throw new HttpsError('failed-precondition', 'El retorno de Wompi no está configurado.');
  }
  if (volver.protocol !== 'https:') {
    throw new HttpsError('failed-precondition', 'El retorno de Wompi debe usar HTTPS.');
  }
  volver.searchParams.set('retorno_wompi', '1');
  const referencia = `CL-PLAN-${randomUUID()}`;
  const centavos = PRECIOS_CENTAVOS[rol];
  await intentos.doc(referencia).create({ uid, rol, centavos, ambiente, creado: Timestamp.now() });
  const url = new URL('https://checkout.wompi.co/p/');
  url.search = new URLSearchParams({
    'public-key': llave, 'currency': 'COP', 'amount-in-cents': String(centavos),
    reference: referencia, 'signature:integrity': sha256(`${referencia}${centavos}COP${secreto}`),
    'customer-data:email': correo, 'redirect-url': volver.href,
  }).toString();
  return { url: url.href };
}

async function confirmarPago(id, uid) {
  const pago = await transaccionWompi(id);
  if (!/^CL-PLAN-[a-f0-9-]{36}$/.test(pago?.reference ?? '')) return { status: 'NOT_FOUND' };
  const intentoRef = intentos.doc(pago.reference);
  const pagoRef = pagos.doc(id);
  return db.runTransaction(async (tx) => {
    const intento = (await tx.get(intentoRef)).data();
    if (!intento || (uid && intento.uid !== uid) || intento.ambiente !== wompi().ambiente) {
      return { status: 'NOT_FOUND' };
    }
    const susRef = typeof intento.suscripcion === 'string'
      ? cobros.suscripciones.doc(intento.suscripcion) : null;
    const sus = susRef ? (await tx.get(susRef)).data() : null;
    if (susRef && (sus?.uid !== intento.uid || sus.fuente !== Number(pago.payment_source_id))) {
      return { status: 'NOT_FOUND' };
    }
    if (!validarTransaccion(pago, pago.reference, intento.correo ?? null, intento.centavos)) {
      if (pago.status !== 'APPROVED') cobros.liquidar(tx, susRef, sus, pago);
      return { status: pago.status === 'APPROVED' ? 'NOT_FOUND' : pago.status };
    }
    const cuentaRef = accesos.doc(intento.uid);
    const [registro, acceso] = await tx.getAll(pagoRef, cuentaRef);
    if (registro.exists && registro.data().uid === intento.uid &&
        registro.data().reference === pago.reference) return { status: 'APPROVED' };
    if (registro.exists || intento.transactionId || !acceso.exists) return { status: 'NOT_FOUND' };
    const cuenta = acceso.data();
    const aprobadoEn = Date.parse(pago.finalized_at);
    const ahora = Date.now();
    const inicio = Math.max(
      Number.isFinite(aprobadoEn) ? Math.min(aprobadoEn, ahora) : ahora,
      milisegundos(cuenta.pagadosHasta?.[intento.rol]),
    );
    const hasta = Timestamp.fromMillis(sumarMesColombia(inicio));
    const cambios = { [`pagadosHasta.${intento.rol}`]: hasta };
    if (cuenta.pruebaRol === intento.rol) cambios.pruebaRol = null;
    tx.update(cuentaRef, cambios);
    cobros.liquidar(tx, susRef, sus, pago, hasta);
    tx.update(intentoRef, { transactionId: id });
    tx.create(pagoRef, {
      uid: intento.uid, transactionId: id, reference: pago.reference,
      rolId: intento.rol, status: 'APPROVED', amountInCents: intento.centavos,
      inicio: Timestamp.fromMillis(inicio), vence: hasta,
    });
    return { status: 'APPROVED' };
  });
}

export const identidadCuenta = onCall(opciones, async (request) => {
  verificarApp(request);
  if (!request.auth) throw new HttpsError('unauthenticated', 'Inicia sesión para continuar.');
  const { uid, token } = request.auth;
  if (request.data?.cedula != null) await registrarIntentoCedula(db, uid);
  return vincularCedula(db, uid, correoNormal(token.email), request.data?.cedula);
});

export const accesoPlan = onCall({ ...opciones, secrets: [integridad, privada] }, async (request) => {
  verificarApp(request);
  if (!request.auth) throw new HttpsError('unauthenticated', 'Inicia sesión para continuar.');
  const { uid, token } = request.auth;
  const { accion, rol, id } = request.data ?? {};
  if (!['estado', 'iniciarPago', 'confirmarPago', 'cancelarRenovacion'].includes(accion)) {
    throw new HttpsError('invalid-argument', 'La acción solicitada no existe.');
  }
  const correo = correoNormal(token.email);
  if (adminCorreos.includes(correo)) {
    if (token.email_verified !== true) {
      throw new HttpsError('permission-denied', 'Verifica el correo de tu cuenta administradora.');
    }
    if (accion !== 'estado') {
      throw new HttpsError('failed-precondition', 'Tu cuenta administradora ya tiene todos los roles.');
    }
    await cuentaAdministradora(uid);
    return {
      ahora: Date.now(),
      roles: [...Object.keys(PRECIOS_CENTAVOS), ...ROLES_GRATUITOS, 'empresa_licitante', 'veeduria_ciudadana'],
      rolInicial: 'persona', pruebaRol: null, pruebaHasta: 0,
      graciaEquipoHasta: 0, preparando: false, pagadosHasta: {}, historicos: [],
      esAdmin: true,
    };
  }
  if (accion === 'confirmarPago') return confirmarPago(id, uid);
  if (accion === 'cancelarRenovacion') return cobros.cancelar(uid, rol);
  const perfil = (await usuarios.doc(uid).get()).data() ?? {};
  if (perfil.cedulaVinculada !== true) {
    if (accion !== 'estado') {
      throw new HttpsError('failed-precondition', 'Vincula tu cédula antes de contratar un plan.');
    }
    return {
      ahora: Date.now(), roles: [], rolInicial: perfil.rolInicialRegistro ?? 'persona',
      pruebaRol: null, pruebaHasta: 0, graciaEquipoHasta: 0, preparando: true,
      pagadosHasta: {}, historicos: [], esAdmin: false,
    };
  }
  const cuenta = await obtenerCuenta(uid, perfil);
  if (accion === 'estado') return {
    ...await estado(uid, token, perfil, cuenta),
    renovacionDisponible: habilitarRenovacion.value(),
    renovaciones: await cobros.estado(uid),
  };
  if (habilitarRenovacion.value()) return cobros.iniciar(uid, correo, rol, cuenta);
  return iniciarPago(uid, correo, rol, cuenta);
});

export const checkoutRenovacion = onRequest({ ...opciones, secrets: [integridad, privada] }, async (req, res) => {
  try {
    await cobros.prepararFuente(req, res);
  } catch (error) {
    console.error('Checkout de renovación no disponible', error.code ?? error.name);
    res.status(503).send('No fue posible abrir el pago. Vuelve a Suscripción e inténtalo de nuevo.');
  }
});

export const renovarPlanes = onSchedule({
  ...opciones, schedule: 'every 15 minutes', secrets: [integridad, privada],
}, () => cobros.ejecutar(confirmarPago));

export const eventosWompi = onRequest({ ...opciones, secrets: [eventos, privada] }, async (req, res) => {
  if (req.method !== 'POST') return res.sendStatus(405);
  const evento = req.body;
  if (!firmaEventoValida(evento, eventos.value())) return res.sendStatus(401);
  const pago = evento.data?.transaction;
  if (evento.event === 'transaction.updated' && pago?.id && ['APPROVED', 'DECLINED', 'ERROR', 'VOIDED'].includes(pago.status)) {
    try {
      await confirmarPago(pago.id);
    } catch (error) {
      console.error('No se pudo confirmar el evento Wompi', error.code ?? error.name);
      return res.sendStatus(503);
    }
  }
  return res.sendStatus(200);
});
