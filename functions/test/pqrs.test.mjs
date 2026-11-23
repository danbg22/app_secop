import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

const conEmuladores = !!(process.env.FIRESTORE_EMULATOR_HOST &&
  process.env.FIREBASE_AUTH_EMULATOR_HOST);

test('el buzón protege el radicado, la respuesta y el estado de lectura',
  { skip: !conEmuladores }, async () => {
    initializeApp();
    const db = getFirestore();
    const auth = getAuth();
    const baseAuth = `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}`;
    const nombreDb = `projects/${process.env.GCLOUD_PROJECT}/databases/(default)/documents`;
    const base = `http://${process.env.FIRESTORE_EMULATOR_HOST}/v1/${nombreDb}`;
    const password = 'Pruebas-buzon-2!';

    async function usuario(email, emailVerified = true) {
      const { uid } = await auth.createUser({ email, password, emailVerified });
      const resp = await fetch(`${baseAuth}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=fixture`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, returnSecureToken: true }),
      });
      assert.equal(resp.status, 200);
      return { uid, token: (await resp.json()).idToken };
    }

    const admin = await usuario('ivanbolano19@gmail.com');
    const sinVerificar = await usuario('ibolano@sena.edu.co', false);
    const dueño = await usuario(`autor-${randomUUID()}@example.com`);
    const otro = await usuario(`otro-${randomUUID()}@example.com`);

    function solicitar(quien, ruta, body) {
      return fetch(`${base}${ruta}`, {
        method: body == null ? 'GET' : 'POST',
        headers: { Authorization: `Bearer ${quien.token}`, 'Content-Type': 'application/json' },
        ...(body == null ? {} : { body: JSON.stringify(body) }),
      });
    }

    function escribir(quien, datos, ruta, mascaras, fechaCampo) {
      const trans = fechaCampo ? [{ fieldPath: fechaCampo, setToServerValue: 'REQUEST_TIME' }] : [];
      return solicitar(quien, ':commit', {
        writes: [{
          update: { name: `${nombreDb}/${ruta}`, fields: datos },
          ...(mascaras ? { updateMask: { fieldPaths: mascaras } } : {}),
          updateTransforms: trans,
        }],
      });
    }

    const str = (s) => ({ stringValue: s });
    const id = `PQRS-${randomUUID()}`;
    const ruta = `pqrs_solicitudes/${id}`;
    const modelo = {
      radicado: str(id), uid: str(dueño.uid), tipo_solicitud: str('Petición'),
      asunto: str('Necesito ayuda con mi cuenta'), mensaje: str('Este es el mensaje enviado.'),
      estado: str('Radicado'),
    };
    assert.equal((await escribir(dueño, modelo, ruta, null, 'fecha_creacion')).status, 200);

    const privada = await solicitar(otro, `/${ruta}`);
    assert.equal(privada.status, 403);
    assert.equal((await solicitar(dueño, `/${ruta}`)).status, 200);
    assert.equal((await escribir(otro, { ...modelo, radicado: str('ajena') },
      'pqrs_solicitudes/ajena', null, 'fecha_creacion')).status, 403);

    const global = await solicitar(dueño, ':runQuery', {
      structuredQuery: {
        from: [{ collectionId: 'pqrs_solicitudes' }],
        where: { fieldFilter: { field: { fieldPath: 'uid' }, op: 'EQUAL', value: str(dueño.uid) } },
      },
    });
    assert.equal(global.status, 200);
    assert.ok((await global.json()).some((item) => item.document?.name.endsWith(id)));

    const viejo = `usuarios/${dueño.uid}/pqrs_solicitudes/PQRS-LEGADO`;
    await db.doc(viejo).set({
      radicado: 'PQRS-LEGADO', uid: dueño.uid, tipo_solicitud: 'Petición',
      asunto: 'Radicado histórico', mensaje: 'Mensaje del expediente previo.',
      estado: 'Radicado', fecha_creacion: Timestamp.now(),
    });
    const consulta = {
      structuredQuery: {
        from: [{ collectionId: 'pqrs_solicitudes', allDescendants: true }],
        orderBy: [{ field: { fieldPath: 'fecha_creacion' }, direction: 'DESCENDING' }],
        limit: 30,
      },
    };
    assert.equal((await solicitar(otro, ':runQuery', consulta)).status, 403);
    assert.equal((await solicitar(sinVerificar, ':runQuery', consulta)).status, 403);
    const bandeja = await solicitar(admin, ':runQuery', consulta);
    assert.equal(bandeja.status, 200);
    const nombres = (await bandeja.json()).map((item) => item.document?.name ?? '');
    assert.ok(nombres.some((nombre) => nombre.endsWith(ruta)));
    assert.ok(nombres.some((nombre) => nombre.endsWith(viejo)));

    const respuesta = {
      estado: str('Respondido'),
      respuesta: { mapValue: { fields: { texto: str('Ya revisamos tu consulta.'), autor_uid: str(admin.uid) } } },
    };
    const responder = (quien, path) => escribir(quien, respuesta, path, ['estado', 'respuesta'], 'respuesta.enviada_en');
    assert.equal((await responder(dueño, ruta)).status, 403);
    assert.equal((await responder(sinVerificar, ruta)).status, 403);
    assert.equal((await responder(admin, ruta)).status, 200);
    assert.equal((await responder(admin, ruta)).status, 403);
    assert.equal((await responder(admin, viejo)).status, 200);

    for (const path of [ruta, viejo]) {
      const recibido = await solicitar(dueño, `/${path}`);
      assert.equal(recibido.status, 200);
      const contenido = (await recibido.json()).fields;
      assert.equal(contenido.respuesta.mapValue.fields.texto.stringValue, 'Ya revisamos tu consulta.');
      assert.equal(contenido.respuesta_leida_en, undefined);
      const lectura = { respuesta_leida_en: contenido.respuesta.mapValue.fields.enviada_en };
      assert.equal((await escribir(otro, lectura, path, ['respuesta_leida_en'])).status, 403);
      assert.equal((await escribir(dueño, lectura, path, ['respuesta_leida_en'])).status, 200);
    }
  });
