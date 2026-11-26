import { randomUUID } from 'node:crypto';
import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { DIA, PRECIOS_CENTAVOS, esPlanPago, sha256 } from './planes.mjs';

const MINUTO = 60000;
const minutos = (n) => Timestamp.fromMillis(Date.now() + n * MINUTO);
const ms = (fecha) => fecha?.toMillis() ?? 0;
const referencia = () => `CL-PLAN-${randomUUID()}`;
export const referenciaValida = (valor) => /^CL-PLAN-[a-f0-9-]{36}$/.test(valor ?? '');
export const cancelaAntesDelCorte = (ahora, vence) => vence - ahora >= DIA;
const terminales = new Set(['DECLINED', 'ERROR', 'VOIDED']);
const escapar = (texto) => String(texto).replace(/[&<>"']/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

export function renovaciones({ db, wompi, privada, integridad, retorno, endpoint, disponible }) {
  const suscripciones = db.collection('suscripciones_planes');
  const intentos = db.collection('intentos_pago_planes');
  const accesos = db.collection('accesos_planes');
  const refPlan = (uid, rol) => suscripciones.doc(sha256(`${uid}:${rol}`));

  async function api(ruta, { metodo = 'GET', datos, publica = false } = {}) {
    const { host, llave, ambiente } = wompi();
    const credencial = publica ? llave : privada.value();
    if (!publica && !credencial.startsWith(`prv_${ambiente}_`)) {
      throw new HttpsError('failed-precondition', 'Credenciales de Wompi fuera de ambiente.');
    }
    const respuesta = await fetch(`https://${host}.wompi.co/v1/${ruta}`, {
      method: metodo,
      // GET /merchants/info se identifica con la llave pública en su propio
      // encabezado; el resto del API usa Authorization: Bearer.
      headers: ruta === 'merchants/info'
        ? { 'x-merchant-public-key': credencial }
        : { Authorization: `Bearer ${credencial}`, 'Content-Type': 'application/json' },
      ...(datos ? { body: JSON.stringify(datos) } : {}),
      signal: AbortSignal.timeout(12000),
    });
    if (!respuesta.ok) throw new HttpsError('unavailable', 'Wompi no confirmó la operación.');
    return (await respuesta.json()).data;
  }

  async function iniciar(uid, correo, rol, cuenta) {
    if (!esPlanPago(rol) || !correo || !cuenta || cuenta.historicos?.includes(rol)) {
      throw new HttpsError('failed-precondition', 'Este plan no requiere una renovación nueva.');
    }
    const actual = (await refPlan(uid, rol).get()).data();
    if (['activa', 'registrando', 'verificando', 'revision'].includes(actual?.estado)) {
      throw new HttpsError('already-exists', 'Ya existe una suscripción o un pago en verificación.');
    }
    const { ambiente } = wompi();
    const ref = referencia();
    const url = new URL(endpoint());
    await intentos.doc(ref).create({
      uid, rol, correo, ambiente, centavos: PRECIOS_CENTAVOS[rol],
      checkoutRecurrente: true, venceSesion: minutos(20),
      creado: Timestamp.now(),
    });
    url.searchParams.set('sesion', ref);
    return { url: url.href, recurrente: true };
  }

  function datosPublicos(datos) {
    return {
      estado: datos.estado,
      renovacion: ms(datos.vencimiento),
      cancelaDespues: datos.cancelaDespues === true,
    };
  }

  async function estado(uid) {
    const docs = await suscripciones.where('uid', '==', uid).get();
    return Object.fromEntries(docs.docs.map((doc) => [doc.data().rol, datosPublicos(doc.data())]));
  }

  async function cancelar(uid, rol) {
    if (!esPlanPago(rol)) throw new HttpsError('invalid-argument', 'Plan no válido.');
    const ref = refPlan(uid, rol);
    return db.runTransaction(async (tx) => {
      const doc = (await tx.get(ref)).data();
      if (!doc) throw new HttpsError('not-found', 'Tu plan no tiene renovación automática.');
      if (!['activa', 'registrando', 'verificando', 'revision'].includes(doc.estado)) return datosPublicos(doc);
      const alVencer = doc.estado === 'registrando' ||
        (doc.estado === 'activa' && cancelaAntesDelCorte(Date.now(), ms(doc.vencimiento)));
      const cambios = alVencer
        ? { estado: 'cancelada', proximo: null, cancelaDespues: false }
        : { cancelaDespues: true };
      tx.update(ref, { ...cambios, canceladoEn: Timestamp.now() });
      return datosPublicos({ ...doc, ...cambios });
    });
  }

  async function autorizaciones() {
    // GET /merchants/{llave} dejó de funcionar el 31 de octubre de 2026.
    const comercio = await api('merchants/info', { publica: true });
    const terminos = comercio?.presigned_acceptance;
    const datos = comercio?.presigned_personal_data_auth;
    function valido(obj) {
      return typeof obj?.acceptance_token === 'string' &&
        /^https:\/\/([a-z0-9-]+\.)*wompi\.(co|com)\//i.test(obj.permalink ?? '');
    }
    if (!valido(terminos) || !valido(datos)) {
      throw new HttpsError('unavailable', 'Wompi no devolvió sus autorizaciones.');
    }
    return { terminos, datos };
  }

  async function prepararFuente(req, res) {
    res.set('Cache-Control', 'no-store');
    res.set('Referrer-Policy', 'no-referrer');
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('X-Frame-Options', 'DENY');
    if (!disponible()) return res.sendStatus(503);
    if (!['GET', 'POST'].includes(req.method)) return res.sendStatus(405);
    const id = req.query.sesion;
    if (typeof id !== 'string' || !referenciaValida(id)) return res.sendStatus(404);
    const ref = intentos.doc(id);
    const original = (await ref.get()).data();
    const { llave, ambiente } = wompi();
    if (!original?.checkoutRecurrente || original.ambiente !== ambiente ||
        ms(original.venceSesion) <= Date.now() || original.tokenRecibido) {
      if (req.method !== 'GET') return res.sendStatus(410);
      const volver = await enlaceRetorno();
      return res.status(410).type('html').send(pagina('Este enlace de pago ya no está disponible',
        `<p>Desde Suscripción puedes consultar tu plan o abrir un nuevo pago.</p>
        <a class="volver" href="${escapar(volver.href)}">Volver a Contrata Legal</a>`));
    }

    if (req.method === 'GET') {
      const permisos = await autorizaciones();
      await ref.update({
        terminosWompi: permisos.terminos.acceptance_token,
        datosWompi: permisos.datos.acceptance_token,
      });
      const precio = new Intl.NumberFormat('es-CO', { maximumFractionDigits: 2 }).format(original.centavos / 100);
      const volver = await enlaceRetorno();
      const destino = `?sesion=${encodeURIComponent(id)}`;
      return res.type('html').send(pagina('Suscripción mensual', `
        <div class="resumen">
          <p class="precio">$${precio} <span>COP al mes</span></p>
          <p>Renovación mensual. Si ya pagaste este periodo, el próximo cobro será al vencimiento.</p>
          <p>Puedes cancelar desde Suscripción hasta 24 horas antes del siguiente cobro.</p>
        </div>
        <form id="mandato" method="POST" action="${escapar(destino)}">
          <div class="autorizaciones">
            <div><input id="autorizar" type="checkbox" name="autorizar" value="si" required>
              <label for="autorizar">Acepto los cobros mensuales y los <a target="_blank" rel="noopener noreferrer" href="${escapar(permisos.terminos.permalink)}">términos de Wompi</a>.</label>
            </div>
            <div><input id="datos" type="checkbox" name="datos" value="si" required>
              <label for="datos">Acepto el <a target="_blank" rel="noopener noreferrer" href="${escapar(permisos.datos.permalink)}">tratamiento de mis datos por Wompi</a>.</label>
            </div>
          </div>
          <p id="estado-wompi" role="status">Cargando el pago…</p>
          <noscript><p>Activa JavaScript en tu navegador para abrir Wompi.</p></noscript>
          <script defer src="https://checkout.wompi.co/widget.js" data-render="button"
            data-widget-operation="tokenize" data-public-key="${escapar(llave)}"></script>
        </form>
        <p class="proveedor">Pago procesado por Wompi</p>
        <a class="volver" href="${escapar(volver.href)}">Volver a Contrata Legal</a>
        <script>
          const formulario = document.getElementById('mandato');
          const estado = document.getElementById('estado-wompi');
          let boton;
          function actualizar() {
            const encontrado = formulario.querySelector('button.waybox-button');
            if (!encontrado) return;
            if (boton !== encontrado) {
              boton = encontrado;
              boton.classList.add('continuar');
              boton.textContent = 'Continuar a Wompi';
              estado.hidden = true;
            }
            boton.disabled = !formulario.elements.autorizar.checked || !formulario.elements.datos.checked;
          }
          function mostrarError() {
            if (boton) return;
            estado.replaceChildren('No se pudo cargar Wompi. ');
            const reintentar = document.createElement('button');
            reintentar.type = 'button';
            reintentar.textContent = 'Reintentar';
            reintentar.addEventListener('click', () => location.reload());
            estado.append(reintentar);
          }
          formulario.querySelector('script[src]').addEventListener('error', mostrarError);
          formulario.addEventListener('change', actualizar);
          new MutationObserver(actualizar).observe(formulario, {childList: true});
          setTimeout(mostrarError, 10000);
          actualizar();
        </script>`));
    }

    const { payment_source_token: token, payment_source_type: tipo, autorizar, datos } = req.body ?? {};
    if (![ 'CARD', 'card' ].includes(tipo) || typeof token !== 'string' ||
        !new RegExp(`^tok_${ambiente}_[A-Za-z0-9_-]{8,200}$`).test(token) ||
        autorizar !== 'si' || datos !== 'si') return res.sendStatus(400);

    const mandato = refPlan(original.uid, original.rol);
    const reclamada = await db.runTransaction(async (tx) => {
      const [sesion, anterior] = await tx.getAll(ref, mandato);
      const actual = sesion.data();
      if (actual?.tokenRecibido || ms(actual?.venceSesion) <= Date.now() ||
          !actual.terminosWompi || !actual.datosWompi ||
          ['activa', 'verificando', 'revision', 'registrando'].includes(anterior.data()?.estado)) return null;
      tx.update(ref, {
        tokenRecibido: true,
        terminosWompi: FieldValue.delete(),
        datosWompi: FieldValue.delete(),
      });
      tx.set(mandato, {
        uid: actual.uid, correo: actual.correo, rol: actual.rol,
        ambiente, centavos: actual.centavos, estado: 'registrando',
        sesion: id, autorizadoEn: Timestamp.now(), proximo: minutos(5),
      });
      return actual;
    });
    if (!reclamada) return res.sendStatus(409);

    try {
      const fuente = await api('payment_sources', {
        metodo: 'POST',
        datos: {
          type: 'CARD', token, customer_email: reclamada.correo,
          acceptance_token: reclamada.terminosWompi,
          accept_personal_auth: reclamada.datosWompi,
        },
      });
      if (fuente?.status !== 'AVAILABLE' || !Number.isSafeInteger(fuente.id)) {
        throw new HttpsError('failed-precondition', 'La tarjeta aún no está disponible.');
      }
      const pendiente = await db.runTransaction(async (tx) => {
        const [sus, cuenta] = await tx.getAll(mandato, accesos.doc(reclamada.uid));
        if (sus.data()?.estado !== 'registrando' || sus.data()?.sesion !== id || !cuenta.exists) return null;
        const base = { fuente: fuente.id, autorizadoEn: Timestamp.now() };
        const vence = ms(cuenta.data().pagadosHasta?.[reclamada.rol]);
        if (vence > Date.now()) {
          tx.update(mandato, { ...base, estado: 'activa', vencimiento: Timestamp.fromMillis(vence), proximo: Timestamp.fromMillis(vence) });
          return false;
        }
        tx.update(ref, { suscripcion: mandato.id });
        tx.update(mandato, { ...base, estado: 'verificando', pendiente: id, proximo: Timestamp.now() });
        return true;
      });
      if (pendiente == null) return res.sendStatus(409);
      const transaccion = pendiente ? await procesar(mandato, null) : null;
      return res.redirect(303, (await enlaceRetorno(transaccion?.id)).href);
    } catch (error) {
      await db.runTransaction(async (tx) => {
        const actual = (await tx.get(mandato)).data();
        if (actual?.estado === 'registrando' && actual.sesion === id) {
          tx.update(mandato, { estado: 'fallida', proximo: null });
        }
      });
      console.error('Alta de renovación no confirmada', error.code ?? error.name);
      const volver = await enlaceRetorno();
      return res.status(502).type('html').send(pagina('Tarjeta no vinculada',
        `<p>Wompi no confirmó la tarjeta. Puedes intentarlo de nuevo.</p><a href="${escapar(volver.href)}">Volver a Contrata Legal</a>`));
    }
  }

  async function enlaceRetorno(id) {
    const url = new URL(retorno());
    if (url.protocol !== 'https:') throw new Error('El retorno debe usar HTTPS');
    if (id) {
      url.searchParams.set('retorno_wompi', '1');
      url.searchParams.set('id', id);
    }
    return url;
  }

  async function procesar(ref, confirmarPago) {
    const trabajo = await db.runTransaction(async (tx) => {
      const doc = (await tx.get(ref)).data();
      if (!doc || ms(doc.proximo) > Date.now() || !doc.proximo) return null;
      if (doc.estado === 'registrando') {
        tx.update(ref, { estado: 'fallida', proximo: null });
        return null;
      }
      if (doc.ambiente !== wompi().ambiente) return null;
      if (doc.estado === 'activa') {
        const id = referencia();
        tx.create(intentos.doc(id), {
          uid: doc.uid, rol: doc.rol, ambiente: doc.ambiente, centavos: doc.centavos,
          correo: doc.correo, suscripcion: ref.id, creado: Timestamp.now(),
        });
        tx.update(ref, {
          estado: 'verificando', pendiente: id, envios: 1, proximo: minutos(5),
        });
        return { ...doc, pendiente: id };
      }
      if (doc.estado !== 'verificando') return null;
      if (doc.idProveedor) {
        tx.update(ref, { proximo: minutos(10) });
        return { idProveedor: doc.idProveedor };
      }
      if ((doc.envios ?? 0) >= 3) {
        tx.update(ref, { estado: 'revision', proximo: null });
        return null;
      }
      tx.update(ref, { envios: (doc.envios ?? 0) + 1, proximo: minutos(5) });
      return doc;
    });
    if (!trabajo) return null;
    try {
      if (trabajo.idProveedor) {
        await confirmarPago?.(trabajo.idProveedor);
        return null;
      }
      const { ambiente } = wompi();
      const secreto = integridad.value();
      if (!secreto.startsWith(`${ambiente}_integrity_`)) throw new Error('Firma fuera de ambiente');
      const transaccion = await api('transactions', {
        metodo: 'POST',
        datos: {
          amount_in_cents: trabajo.centavos, currency: 'COP', customer_email: trabajo.correo,
          reference: trabajo.pendiente,
          signature: sha256(`${trabajo.pendiente}${trabajo.centavos}COP${secreto}`),
          payment_source_id: trabajo.fuente, payment_method: { installments: 1 },
          recurrent: true,
        },
      });
      if (typeof transaccion?.id !== 'string' || transaccion.reference !== trabajo.pendiente) return null;
      await db.runTransaction(async (tx) => {
        const actual = (await tx.get(ref)).data();
        if (actual?.pendiente === trabajo.pendiente) tx.update(ref, { idProveedor: transaccion.id });
      });
      if (transaccion.status !== 'PENDING') await confirmarPago?.(transaccion.id);
      return transaccion;
    } catch (error) {
      console.error('Cobro recurrente pendiente de confirmación', error.code ?? error.name);
      return null;
    }
  }

  async function ejecutar(confirmarPago) {
    if (!disponible()) return;
    const lotes = await suscripciones.where('proximo', '<=', Timestamp.now()).limit(60).get();
    const resultados = await Promise.allSettled(lotes.docs.map((doc) => procesar(doc.ref, confirmarPago)));
    const fallidas = resultados.filter((resultado) => resultado.status === 'rejected').length;
    if (fallidas) console.error('No se pudieron procesar renovaciones', fallidas);
  }

  function liquidar(tx, ref, doc, pago, hasta) {
    if (!ref || doc?.pendiente !== pago.reference) return;
    if (pago.status === 'APPROVED') {
      const cancelada = doc.cancelaDespues === true;
      tx.update(ref, {
        estado: cancelada ? 'cancelada' : 'activa',
        vencimiento: hasta, proximo: cancelada ? null : hasta,
        pendiente: null, idProveedor: null, envios: 0,
      });
    } else if (terminales.has(pago.status)) {
      tx.update(ref, { estado: 'fallida', proximo: null, pendiente: null, idProveedor: null });
    }
  }

  return { iniciar, estado, cancelar, prepararFuente, ejecutar, liquidar, suscripciones };
}

function pagina(titulo, contenido) {
  return `<!doctype html><html lang="es"><head><meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapar(titulo)} · Contrata Legal</title><style>
  *{box-sizing:border-box}
  body{margin:0;min-height:100vh;padding:clamp(18px,7vh,72px) 16px;background:
    radial-gradient(ellipse at 8% 0%,#1c3c80 0%,transparent 52%),
    radial-gradient(ellipse at 100% 100%,#3a2d17 0%,transparent 45%),#07101f;
    color:#f8fafc;font:15px/1.5 system-ui,sans-serif;color-scheme:dark}
  main{max-width:538px;margin:auto;padding:clamp(20px,5vw,32px);background:#111f35;
    border:1px solid #ffffff20;border-radius:24px;box-shadow:0 24px 72px #03081266}
  .marca{color:#ffc53d;font-weight:750}
  h1{font-size:clamp(1.65rem,5vw,2rem);line-height:1.14;letter-spacing:-.025em;margin:8px 0 20px}
  p{margin:0 0 10px;color:#c3d0e4} p:last-child{margin-bottom:0}
  .resumen{padding:16px;border:1px solid #ffffff17;border-radius:16px;background:#ffffff08}
  .precio{color:#fff;font-size:1.7rem;font-weight:800;letter-spacing:-.025em}
  .precio span{font-size:.89rem;color:#ffc53d;letter-spacing:normal}
  .autorizaciones{display:grid;gap:12px;margin:20px 0}
  .autorizaciones div{display:grid;grid-template-columns:20px 1fr;gap:10px;align-items:start}
  input[type=checkbox]{width:18px;height:18px;margin:2px 0 0;accent-color:#ffc53d}
  a{color:#a9ccff;text-underline-offset:3px}
  #mandato button.continuar{display:block;width:100%;min-height:50px;padding:12px 18px;
    border:0;border-radius:999px;background:#ffc53d;color:#0a1424;font:inherit;font-weight:800;cursor:pointer}
  #mandato button.continuar:not(:disabled):hover{background:#ffda74}
  #mandato button.continuar:disabled{background:#ffc53d40;color:#ffedbc;cursor:default;opacity:1}
  :focus-visible{outline:2px solid #93c5fd;outline-offset:4px}
  #estado-wompi button{background:none;border:0;color:#a9ccff;text-decoration:underline;font:inherit;cursor:pointer}
  .proveedor{text-align:center;font-size:.81rem;color:#aebed5;margin:10px 0 16px}
  .volver{display:inline-block;margin-top:8px;font-size:.89rem}
  </style></head><body><main><span class="marca">Contrata Legal</span><h1>${escapar(titulo)}</h1>${contenido}</main></body></html>`;
}
