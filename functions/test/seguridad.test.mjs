// Pruebas de las reglas de Firestore contra el emulador: cada bloqueo de la
// auditoría de seguridad (rama security-audit) se demuestra con una petición
// real, sin sesión (quien solo tiene el enlace) o con usuarios del emulador.
import assert from 'node:assert/strict';
import { randomBytes, randomUUID } from 'node:crypto';
import test from 'node:test';
import { initializeApp, getApps } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const conEmuladores = !!(process.env.FIRESTORE_EMULATOR_HOST &&
  process.env.FIREBASE_AUTH_EMULATOR_HOST);

function valor(v) {
  if (v === null) return { nullValue: null };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (typeof v === 'string') return { stringValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(valor) } };
  return { mapValue: { fields: campos(v) } };
}
const campos = (obj) => Object.fromEntries(Object.entries(obj).map(([k, v]) => [k, valor(v)]));

test('las reglas bloquean los accesos indebidos de la auditoría', { skip: !conEmuladores }, async () => {
  if (!getApps().length) initializeApp();
  const db = getFirestore();
  const auth = getAuth();
  const base = `http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${process.env.GCLOUD_PROJECT}/databases/(default)/documents`;
  const baseAuth = `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`;

  async function sesion({ email = `seg-${randomUUID()}@example.com`, verificado = true } = {}) {
    const password = 'Pruebas-seguridad-26';
    const { uid } = await auth.createUser({ email, password, emailVerified: verificado });
    const r = await fetch(`${baseAuth}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=local`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    });
    return { uid, email, idToken: (await r.json()).idToken };
  }
  const pedir = (ruta, { usuario, metodo = 'GET', datos, mascara } = {}) => {
    const q = mascara ? '?' + mascara.map((m) => `updateMask.fieldPaths=${m}`).join('&') : '';
    return fetch(`${base}/${ruta}${q}`, {
      method: metodo,
      headers: {
        'Content-Type': 'application/json',
        ...(usuario ? { Authorization: `Bearer ${usuario.idToken}` } : {}),
      },
      ...(datos ? { body: JSON.stringify({ fields: campos(datos) }) } : {}),
    });
  };

  // --- Enlace del contratista desactivable -------------------------------
  const token = randomBytes(16).toString('hex');
  const expediente = {
    tokenInvitado: token, numeroContrato: 'CPS-SEG-1', objetoContrato: 'Objeto',
    creadoPorUid: 'equipo-x', equipoUid: 'equipo-x',
    apartados: [{ id: 'apt-aprobado' }, { id: 'apt-pendiente' }],
    trazabilidad: [],
    decisiones: { 'apt-aprobado': { estado: 'APROBADO', version: 1 } },
  };
  await db.doc(`expedientes_juridicos/${token}`).set(expediente);
  await db.doc(`expedientes_juridicos/${token}/archivos/apt-aprobado`).set({ archivoBase64: 'QUJD' });

  assert.equal((await pedir(`expedientes_juridicos/${token}`)).status, 200,
    'con el enlace vigente se lee el expediente');

  // Un documento aprobado no se reemplaza desde el enlace; uno pendiente, sí.
  assert.equal((await pedir(`expedientes_juridicos/${token}/archivos/apt-aprobado`, {
    metodo: 'PATCH', datos: { archivoBase64: 'T1RSTw==' },
  })).status, 403, 'no se reemplaza un archivo aprobado');
  assert.equal((await pedir(`expedientes_juridicos/${token}/archivos/apt-pendiente`, {
    metodo: 'PATCH', datos: { archivoBase64: 'TlVFVk8=' },
  })).status, 200, 'el contratista sube un documento pendiente');

  // Desde el enlace no se tocan las decisiones del equipo ni el propio enlace.
  assert.equal((await pedir(`expedientes_juridicos/${token}`, {
    metodo: 'PATCH', mascara: ['decisiones'],
    datos: { decisiones: { 'apt-pendiente': { estado: 'APROBADO', version: 1 } } },
  })).status, 403, 'el contratista no se aprueba documentos');
  assert.equal((await pedir(`expedientes_juridicos/${token}`, {
    metodo: 'PATCH', mascara: ['enlaceDesactivado'], datos: { enlaceDesactivado: false },
  })).status, 403, 'el contratista no maneja el enlace');

  // El equipo desactiva el enlace: ya no se lee ni se escribe con él.
  await db.doc(`expedientes_juridicos/${token}`).update({ enlaceDesactivado: true });
  assert.equal((await pedir(`expedientes_juridicos/${token}`)).status, 403,
    'enlace desactivado: no se lee');
  assert.equal((await pedir(`expedientes_juridicos/${token}/archivos/apt-aprobado`)).status, 403,
    'enlace desactivado: no se leen sus archivos');
  assert.equal((await pedir(`expedientes_juridicos/${token}/archivos/apt-pendiente`, {
    metodo: 'PATCH', datos: { archivoBase64: 'T1RSTw==' },
  })).status, 403, 'enlace desactivado: no se suben archivos');

  // --- Invitaciones del equipo: solo con el correo verificado ---------------
  const correo = `abogado-${randomUUID()}@example.com`;
  await db.doc(`miembros_equipo/${correo}`).set({ email: correo, masterUid: 'equipo-x', estado: 'activo' });
  const sinVerificar = await sesion({ email: correo, verificado: false });
  assert.equal((await pedir(`miembros_equipo/${correo}`, { usuario: sinVerificar })).status, 403,
    'con el correo sin verificar no se lee la invitación');
  await auth.updateUser(sinVerificar.uid, { emailVerified: true });
  const verificado = await sesion({ email: `otro-${randomUUID()}@example.com` });
  assert.equal((await pedir(`miembros_equipo/${correo}`, { usuario: verificado })).status, 403,
    'nadie lee la invitación de otro correo');

  // --- Perfiles: sin escalar privilegios ni leer los de otros ---------------
  const ana = await sesion();
  const beto = await sesion();
  await db.doc(`usuarios/${ana.uid}`).set({ uid: ana.uid, email: ana.email, rolesActivos: ['contratista'] });
  assert.equal((await pedir(`usuarios/${ana.uid}`, { usuario: beto })).status, 403,
    'no se lee el perfil de otro');
  assert.equal((await pedir(`usuarios/${ana.uid}`, {
    usuario: ana, metodo: 'PATCH', mascara: ['rolesActivos'],
    datos: { rolesActivos: ['contratista', 'equipo_juridico'] },
  })).status, 403, 'no se agrega un rol de pago');
  assert.equal((await pedir(`usuarios/${ana.uid}`, {
    usuario: ana, metodo: 'PATCH', mascara: ['pagoWompiActivo'], datos: { pagoWompiActivo: true },
  })).status, 403, 'no se marca un pago');
  assert.equal((await pedir(`accesos_planes/${ana.uid}`, {
    usuario: ana, metodo: 'PATCH', datos: { historicos: ['equipo_juridico'] },
  })).status, 403, 'no se escriben vigencias');
  assert.equal((await pedir('limites_cedula/' + ana.uid, { usuario: ana })).status, 403,
    'los límites de intentos son solo del servidor');
});
