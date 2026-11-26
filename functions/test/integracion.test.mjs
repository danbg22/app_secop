import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { DIA, PRECIOS_CENTAVOS, sha256, sumarMesColombia } from '../planes.mjs';

const conEmuladores = !!(process.env.FIRESTORE_EMULATOR_HOST &&
  process.env.FIREBASE_AUTH_EMULATOR_HOST);

test('alta, vigencia de Firestore, corte, pago anticipado y confirmación idempotente',
  { skip: !conEmuladores }, async () => {
    process.env.PLANES_INICIO_PRUEBA = new Date(Date.now() - DIA).toISOString();
    process.env.WOMPI_PUBLIC_KEY = 'pub_test_fixture';
    process.env.WOMPI_PRIVATE_KEY = 'prv_test_fixture';
    process.env.WOMPI_INTEGRITY_SECRET = 'test_integrity_fixture';
    process.env.WOMPI_RENOVACION_ACTIVA = 'true';
    process.env.PLANES_RETORNO = 'https://contratalegal.com/';
    const { accesoPlan } = await import('../index.mjs');
    const auth = getAuth();
    const db = getFirestore();
    const baseAuth = `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`;
    const baseDb = `http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${process.env.GCLOUD_PROJECT}/databases/(default)/documents`;
    const password = 'Pruebas-electronicas-26';

    async function alta(rol, documento) {
      const email = `plan-${randomUUID()}@example.com`;
      const usuario = await auth.createUser({ email, password, emailVerified: true });
      const { uid } = usuario;
      await db.collection('usuarios').doc(uid).set({
        uid, email, rolInicialRegistro: rol, rolSolicitadoRegistro: rol,
        documentoNormalizado: documento, cedulaVinculada: true, rolesActivos: ['contratista'],
      });
      const huella = sha256(`ContrataLegal::SECOP::AppSec::2026::v1::uniqueness::doc::${documento}`);
      await db.collection('indices_unicidad').doc(huella).set({ uid, tipo: 'doc' });
      const respuesta = await fetch(`${baseAuth}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=local`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, returnSecureToken: true }),
      });
      assert.equal(respuesta.status, 200);
      const { idToken } = await respuesta.json();
      return { uid, email, idToken, creado: Date.parse(usuario.metadata.creationTime) };
    }

    const invocar = (usuario, accion, data) => accesoPlan.run({
      auth: { uid: usuario.uid, token: { email: usuario.email, email_verified: true } },
      data: { accion, ...data },
    });
    const pedir = (usuario, documento, options = {}) => fetch(`${baseDb}/${documento}`, {
      ...options, headers: { Authorization: `Bearer ${usuario.idToken}`, 'Content-Type': 'application/json' },
    });

    const equipo = await alta('equipo_juridico', '126800001');
    const antes = await invocar(equipo, 'estado');
    assert.equal(antes.pruebaHasta, equipo.creado + 30 * DIA);
    assert.ok(antes.roles.includes('equipo_juridico'));
    assert.ok(antes.roles.includes('contratista'));

    const procesoId = 'a'.repeat(32);
    await db.doc(`procesos_contratacion/${procesoId}`).set({ equipoUid: equipo.uid });
    await db.doc('directorio_supervision/800111111/supervisores/test').set({ x: 1 });
    assert.equal((await pedir(equipo, `procesos_contratacion/${procesoId}`)).status, 200);
    assert.equal((await pedir(equipo, `accesos_planes/${equipo.uid}`, {
      method: 'PATCH', body: JSON.stringify({ fields: { historicos: { arrayValue: {
        values: [{ stringValue: 'equipo_juridico' }],
      } } } }),
    })).status, 403);

    await db.doc(`accesos_planes/${equipo.uid}`).update({ pruebaHasta: Timestamp.fromMillis(Date.now() - 1) });
    assert.deepEqual((await invocar(equipo, 'estado')).roles, []);
    assert.equal((await pedir(equipo, `procesos_contratacion/${procesoId}`)).status, 403);
    assert.equal((await pedir(equipo, 'directorio_supervision/800111111/supervisores/test')).status, 403);
    assert.equal((await pedir(equipo, 'pagos_wompi/verificacion-pruebas', {
      method: 'PATCH', body: JSON.stringify({ fields: { uid: { stringValue: equipo.uid } } }),
    })).status, 403);

    const repetido = await alta('persona', '126800001');
    const sinSegundaPrueba = await invocar(repetido, 'estado');
    assert.equal(sinSegundaPrueba.pruebaHasta, 0);
    assert.deepEqual(sinSegundaPrueba.roles, []);

    const persona = await alta('persona', '126800002');
    const prueba = await invocar(persona, 'estado');
    const inicioPago = await invocar(persona, 'iniciarPago', { rol: 'persona' });
    const checkout = new URL(inicioPago.url);
    const referencia = checkout.searchParams.get('reference');
    assert.equal(checkout.origin + checkout.pathname, 'https://checkout.wompi.co/p/');
    assert.equal(checkout.searchParams.get('amount-in-cents'), String(PRECIOS_CENTAVOS.persona));
    assert.equal(checkout.searchParams.get('signature:integrity'),
      sha256(`${referencia}${PRECIOS_CENTAVOS.persona}COPtest_integrity_fixture`));
    assert.equal(checkout.searchParams.get('redirect-url'), 'https://contratalegal.com/?retorno_wompi=1');
    assert.equal(checkout.searchParams.has('customer-data:email'), false);
    assert.equal(checkout.searchParams.has('payment-method'), false);
    const aprobado = Date.now() - 1000;
    const txId = '1234-pruebas-1';
    const recibo = {
      id: txId, status: 'APPROVED', reference: referencia, currency: 'COP',
      amount_in_cents: PRECIOS_CENTAVOS.persona, finalized_at: new Date(aprobado).toISOString(),
      payment_method_type: 'NEQUI',
    };
    const fetchOriginal = globalThis.fetch;
    globalThis.fetch = async (url, options) => {
      if (!String(url).startsWith('https://sandbox.wompi.co/')) return fetchOriginal(url, options);
      assert.equal(new URL(url).pathname, `/v1/transactions/${recibo.id}`);
      assert.equal(options.headers.Authorization, 'Bearer prv_test_fixture');
      return Response.json({ data: recibo });
    };
    try {
      assert.equal((await invocar(equipo, 'confirmarPago', { id: txId })).status, 'NOT_FOUND');
      recibo.status = 'PENDING';
      assert.equal((await invocar(persona, 'confirmarPago', { id: txId })).status, 'PENDING');
      assert.equal((await invocar(persona, 'estado')).pruebaHasta, prueba.pruebaHasta);
      recibo.status = 'APPROVED';
      const respuestas = await Promise.all([
        invocar(persona, 'confirmarPago', { id: txId }),
        invocar(persona, 'confirmarPago', { id: txId }),
      ]);
      assert.ok(respuestas.every((r) => r.status === 'APPROVED'));
      const despues = await invocar(persona, 'estado');
      assert.equal(despues.pruebaRol, null);
      assert.equal(despues.pagadosHasta.persona, sumarMesColombia(aprobado));
      assert.deepEqual(despues.renovaciones, {});
      await assert.rejects(invocar(persona, 'iniciarPago', { rol: 'persona' }), { code: 'already-exists' });

      await db.doc(`accesos_planes/${persona.uid}`).update({
        'pagadosHasta.persona': Timestamp.fromMillis(aprobado - 1),
      });
      const mandato = db.doc(`suscripciones_planes/${sha256(`${persona.uid}:persona`)}`);
      await mandato.set({ uid: persona.uid, rol: 'persona', estado: 'verificando' });
      await assert.rejects(invocar(persona, 'iniciarPago', { rol: 'persona' }), { code: 'already-exists' });
      await mandato.delete();

      const renovacion = new URL((await invocar(persona, 'iniciarPago', { rol: 'persona' })).url);
      const nuevaReferencia = renovacion.searchParams.get('reference');
      assert.notEqual(nuevaReferencia, referencia);
      Object.assign(recibo, { id: '1234-pruebas-2', reference: nuevaReferencia, payment_method_type: 'CARD' });
      assert.equal((await invocar(persona, 'confirmarPago', { id: recibo.id })).status, 'APPROVED');
      const renovado = await invocar(persona, 'estado');
      assert.equal(renovado.pagadosHasta.persona, sumarMesColombia(aprobado));
      assert.deepEqual(renovado.renovaciones, {});
    } finally {
      globalThis.fetch = fetchOriginal;
    }
  });

test('los administradores existentes conservan todos los roles con facturación sin configurar',
  { skip: !conEmuladores }, async () => {
    delete process.env.PLANES_INICIO_PRUEBA;
    delete process.env.WOMPI_PUBLIC_KEY;
    delete process.env.WOMPI_PRIVATE_KEY;
    const { accesoPlan } = await import('../index.mjs');
    const auth = getAuth();
    const db = getFirestore();
    const email = 'danielbg2231@gmail.com';
    const password = 'Administrador-emulador-26';
    const { uid } = await auth.createUser({ email, password, emailVerified: false });
    const cuenta = db.doc(`accesos_planes/${uid}`);
    await cuenta.set({
      rolInicial: 'persona', pruebaRol: 'persona', pruebaHasta: Timestamp.fromMillis(1),
      pagadosHasta: {}, historicos: [], admin: false,
    });
    const ruta = 'procesos_contratacion/' + 'b'.repeat(32);
    await db.doc(ruta).set({ equipoUid: uid });

    async function solicitar(accion, verificado) {
      return accesoPlan.run({
        auth: { uid, token: { email, email_verified: verificado } },
        data: { accion, rol: 'persona' },
      });
    }

    async function consultarExpediente() {
      const baseAuth = `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`;
      const baseDb = `http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/projects/${process.env.GCLOUD_PROJECT}/databases/(default)/documents`;
      const login = await fetch(`${baseAuth}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=local`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, returnSecureToken: true }),
      });
      assert.equal(login.status, 200);
      const { idToken } = await login.json();
      return fetch(`${baseDb}/${ruta}`, {
        headers: { Authorization: `Bearer ${idToken}` },
      });
    }

    await assert.rejects(solicitar('estado', false), { code: 'permission-denied' });
    assert.equal((await consultarExpediente()).status, 403);
    await auth.updateUser(uid, { emailVerified: true });
    const estado = await solicitar('estado', true);
    assert.equal(estado.esAdmin, true);
    assert.equal(estado.pruebaHasta, 0);
    assert.equal((await cuenta.get()).data().pruebaHasta, null);
    assert.deepEqual(new Set(estado.roles), new Set([
      'persona', 'equipo_juridico', 'supervisor_contratos', 'contratista',
      'juridico_supervision', 'empresa_licitante', 'veeduria_ciudadana',
    ]));
    assert.equal((await consultarExpediente()).status, 200);
    await assert.rejects(solicitar('iniciarPago', true), { code: 'failed-precondition' });
  });
