import assert from 'node:assert/strict';
import test from 'node:test';
import {
  DIA, PRECIOS_CENTAVOS, firmaEventoValida, sha256, sumarMesColombia,
  validarTransaccion, vencimientoPrueba,
} from '../planes.mjs';

test('la prueba cuenta 30 días corridos desde la creación individual', () => {
  const lanzamiento = Date.parse('2026-11-23T00:00:00Z');
  assert.equal(vencimientoPrueba(lanzamiento - 1, lanzamiento), null);
  assert.equal(vencimientoPrueba(lanzamiento, lanzamiento), lanzamiento + 30 * DIA);
  const alta = Date.parse('2026-12-20T23:59:59.999Z');
  assert.equal(vencimientoPrueba(alta, lanzamiento), Date.parse('2027-01-19T23:59:59.999Z'));
});

test('el primer ciclo de pago usa un mes calendario en hora de Colombia', () => {
  assert.equal(
    sumarMesColombia(Date.parse('2027-02-01T03:00:00Z')),
    Date.parse('2027-03-01T03:00:00Z'),
  );
  assert.equal(
    sumarMesColombia(Date.parse('2028-01-31T17:00:00Z')),
    Date.parse('2028-02-29T17:00:00Z'),
  );
});

test('solo una aprobación que coincide con la orden permite activar el plan', () => {
  const transaccion = {
    status: 'APPROVED', reference: 'referencia-en-servidor', currency: 'COP',
    amount_in_cents: PRECIOS_CENTAVOS.persona, customer_email: 'Cliente@ejemplo.com',
  };
  const validar = (tx) => validarTransaccion(tx, transaccion.reference, 'cliente@ejemplo.com', PRECIOS_CENTAVOS.persona);
  assert.equal(validar(transaccion), true);
  assert.equal(validar({ ...transaccion, status: 'PENDING' }), false);
  assert.equal(validar({ ...transaccion, amount_in_cents: 1 }), false);
  assert.equal(validar({ ...transaccion, currency: 'USD' }), false);
  assert.equal(validar({ ...transaccion, reference: 'otra-referencia' }), false);
  assert.equal(validar({ ...transaccion, customer_email: 'otra@ejemplo.com' }), false);
});

test('el webhook exige el checksum de Wompi sobre sus campos', () => {
  const properties = ['transaction.id', 'transaction.status', 'transaction.amount_in_cents'];
  const timestamp = 1779123712;
  const secret = 'secreto-fixture';
  const signature = { properties, checksum: sha256(`tx-fixtureAPPROVED10000${timestamp}${secret}`) };
  const transaction = { id: 'tx-fixture', status: 'APPROVED', amount_in_cents: 10000 };
  const evento = { timestamp, signature, data: { transaction } };
  assert.equal(firmaEventoValida(evento, secret), true);
  assert.equal(firmaEventoValida(evento, 'otro'), false);
  assert.equal(firmaEventoValida({ ...evento, timestamp: timestamp + 1 }, secret), false);
});
