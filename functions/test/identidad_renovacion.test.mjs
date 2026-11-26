import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import {
  MAX_INTENTOS_CEDULA, VENTANA_INTENTOS_MS, cedulaCanonica, siguienteIntento, vincularCedula,
} from '../identidad.mjs';
import { cancelaAntesDelCorte, renovaciones } from '../renovaciones.mjs';
import { DIA, sha256, sumarMesColombia } from '../planes.mjs';

test('la cédula se normaliza y el corte de cancelación es de 24 horas exactas', () => {
  assert.equal(cedulaCanonica(' 1.000.123.456 '), '1000123456');
  assert.equal(cedulaCanonica('CC 1000123456'), '');
  assert.equal(cedulaCanonica('1234'), '');
  assert.equal(cancelaAntesDelCorte(1, 1 + DIA), true);
  assert.equal(cancelaAntesDelCorte(2, 1 + DIA), false);
});

const emulador = !!process.env.FIRESTORE_EMULATOR_HOST;

test('el índice registra una sola cuenta y protege perfiles antiguos', { skip: !emulador }, async () => {
  const db = getFirestore(initializeApp({ projectId: process.env.GCLOUD_PROJECT }, 'prueba-identidad'));
  const uidA = randomUUID();
  const uidB = randomUUID();
  const cedula = '1000007888';
  const resultados = await Promise.allSettled([
    vincularCedula(db, uidA, '', cedula),
    vincularCedula(db, uidB, '', '1.000.007.888'),
  ]);
  assert.equal(resultados.filter((r) => r.status === 'fulfilled').length, 1);
  assert.equal(resultados.find((r) => r.status === 'rejected').reason.code, 'already-exists');
  const uidGanador = resultados[0].status === 'fulfilled' ? uidA : uidB;
  assert.deepEqual(await vincularCedula(db, uidGanador, ''), { vinculada: true });
  await assert.rejects(vincularCedula(db, uidGanador, '', '1000007889'), { code: 'failed-precondition' });

  const antigua = randomUUID();
  await db.doc(`usuarios/${antigua}`).set({ documento: '1.000.007.890', documentoNormalizado: '1000007890' });
  await assert.rejects(vincularCedula(db, uidB + '-otro', '', '1000007890'), { code: 'already-exists' });
  assert.deepEqual(await vincularCedula(db, antigua, ''), { vinculada: true });
});

test('la renovación reclama un cobro por ciclo y respeta cancelaciones', { skip: !emulador }, async (t) => {
  const db = getFirestore(initializeApp({ projectId: process.env.GCLOUD_PROJECT }, 'prueba-renovacion'));
  const rol = 'persona';
  const uid = randomUUID();
  const temprano = randomUUID();
  const cobros = renovaciones({
    db,
    wompi: () => ({ host: 'sandbox', llave: 'pub_test_fixture', ambiente: 'test' }),
    privada: { value: () => 'prv_test_fixture' },
    integridad: { value: () => 'test_integrity_fixture' },
    disponible: () => true,
  });
  const ref = cobros.suscripciones.doc(sha256(`${uid}:${rol}`));
  const refTemprano = cobros.suscripciones.doc(sha256(`${temprano}:${rol}`));
  const base = { rol, correo: 'pruebas@example.com', ambiente: 'test', centavos: 10000, estado: 'activa', fuente: 99 };
  const tempranoHasta = Timestamp.fromMillis(Date.now() + 2 * DIA);
  const tardeHasta = Timestamp.fromMillis(Date.now() + DIA / 2);
  await refTemprano.set({ ...base, uid: temprano, vencimiento: tempranoHasta, proximo: tempranoHasta });
  await ref.set({ ...base, uid, vencimiento: tardeHasta, proximo: tardeHasta });

  assert.equal((await cobros.cancelar(temprano, rol)).estado, 'cancelada');
  assert.equal((await cobros.cancelar(uid, rol)).cancelaDespues, true);
  await ref.update({ proximo: Timestamp.now() });
  let envios = 0;
  const original = globalThis.fetch;
  t.mock.method(globalThis, 'fetch', async (url, init) => {
    if (!String(url).startsWith('https://sandbox.wompi.co/')) return original(url, init);
    envios++;
    assert.equal(init.method, 'POST');
    const payload = JSON.parse(init.body);
    assert.equal(payload.payment_source_id, 99);
    assert.equal(payload.recurrent, true);
    assert.equal(payload.amount_in_cents, 10000);
    return Response.json({ data: { id: '123-pago-fixture', reference: payload.reference, status: 'PENDING' } });
  });
  await Promise.all([cobros.ejecutar(() => {}), cobros.ejecutar(() => {})]);
  assert.equal(envios, 1);
  const avance = (await ref.get()).data();
  assert.equal(avance.estado, 'verificando');
  assert.equal(avance.idProveedor, '123-pago-fixture');
  const hasta = Timestamp.fromMillis(sumarMesColombia(tardeHasta.toMillis()));
  await db.runTransaction(async (tx) => {
    const doc = (await tx.get(ref)).data();
    cobros.liquidar(tx, ref, doc, { status: 'APPROVED', reference: doc.pendiente }, hasta);
  });
  assert.equal((await ref.get()).data().estado, 'cancelada');
  assert.equal((await ref.get()).data().proximo, null);
  assert.equal((await ref.get()).data().vencimiento.toMillis(), hasta.toMillis());
  await cobros.ejecutar(() => {});
  assert.equal(envios, 1);
});

test('el alta de tarjeta reclama una sola autorización y redirige a la verificación', { skip: !emulador }, async (t) => {
  const db = getFirestore(initializeApp({ projectId: process.env.GCLOUD_PROJECT }, 'prueba-alta-tarjeta'));
  const uid = randomUUID();
  const cuenta = { pagadosHasta: {}, historicos: [] };
  await db.doc(`accesos_planes/${uid}`).set(cuenta);
  const cobros = renovaciones({
    db,
    wompi: () => ({ host: 'sandbox', llave: 'pub_test_fixture', ambiente: 'test' }),
    privada: { value: () => 'prv_test_fixture' },
    integridad: { value: () => 'test_integrity_fixture' },
    disponible: () => true,
    endpoint: () => 'https://funciones.example.com/checkoutRenovacion',
    retorno: () => 'https://contratalegal.com/',
  });
  const respuesta = () => ({
    set() {},
    type() { return this; },
    send(html) { this.html = html; },
    sendStatus(codigo) { this.codigo = codigo; },
    redirect(codigo, url) { this.codigo = codigo; this.url = url; },
  });
  const retorno = new URL((await cobros.iniciar(uid, 'fixture@example.com', 'persona', cuenta)).url);
  const sesion = retorno.searchParams.get('sesion');
  let altas = 0;
  let cargos = 0;
  const original = globalThis.fetch;
  t.mock.method(globalThis, 'fetch', async (url, init) => {
    if (!String(url).startsWith('https://sandbox.wompi.co/')) return original(url, init);
    if (String(url).includes('/merchants/')) {
      assert.ok(String(url).endsWith('/v1/merchants/info'));
      assert.match(init.headers['x-merchant-public-key'], /^pub_test_/);
    }
    if (String(url).includes('/merchants/')) return Response.json({ data: {
      presigned_acceptance: { permalink: 'https://wompi.co/terminos', acceptance_token: 'terminos' },
      presigned_personal_data_auth: { permalink: 'https://wompi.co/datos', acceptance_token: 'datos' },
    } });
    const cuerpo = JSON.parse(init.body);
    if (String(url).endsWith('/payment_sources')) {
      altas++;
      assert.equal(cuerpo.acceptance_token, 'terminos');
      assert.equal(cuerpo.accept_personal_auth, 'datos');
      return Response.json({ data: { id: 123, status: 'AVAILABLE' } });
    }
    cargos++;
    assert.equal(cuerpo.payment_source_id, 123);
    return Response.json({ data: { id: '987-prueba', reference: cuerpo.reference, status: 'PENDING' } });
  });
  const pagina = respuesta();
  await cobros.prepararFuente({ method: 'GET', query: { sesion } }, pagina);
  assert.match(pagina.html, /data-widget-operation="tokenize"/);
  const cuerpo = { payment_source_token: 'tok_test_tokenfixture', payment_source_type: 'CARD' };
  const rechazada = respuesta();
  await cobros.prepararFuente({ method: 'POST', query: { sesion }, body: cuerpo }, rechazada);
  assert.equal(rechazada.codigo, 400);
  const primera = respuesta();
  const segunda = respuesta();
  const solicitud = { method: 'POST', query: { sesion }, body: { ...cuerpo, autorizar: 'si', datos: 'si' } };
  await Promise.all([cobros.prepararFuente(solicitud, primera), cobros.prepararFuente(solicitud, segunda)]);
  const aceptada = [primera, segunda].find((r) => r.codigo === 303);
  assert.equal(new URL(aceptada.url).searchParams.get('id'), '987-prueba');
  assert.equal(altas, 1);
  assert.equal(cargos, 1);
  const persistida = (await db.doc(`intentos_pago_planes/${sesion}`).get()).data();
  assert.ok(!JSON.stringify(persistida).includes(cuerpo.payment_source_token));
});

test('la vinculación de cédula admite pocos intentos por hora', () => {
  let registro;
  const ahora = 1_000_000;
  for (let i = 0; i < MAX_INTENTOS_CEDULA; i++) {
    registro = siguienteIntento(registro, ahora + i);
    assert.ok(registro, `intento ${i + 1}`);
  }
  assert.equal(siguienteIntento(registro, ahora + 10), null);
  const nuevaHora = siguienteIntento(registro, ahora + VENTANA_INTENTOS_MS + 1);
  assert.deepEqual(nuevaHora, { inicio: ahora + VENTANA_INTENTOS_MS + 1, intentos: 1 });
});

