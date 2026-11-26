import { createHash, timingSafeEqual } from 'node:crypto';

export const DIA = 24 * 60 * 60 * 1000;
export const PRECIOS_CENTAVOS = Object.freeze({
  persona: 1485000, // COP 14.850
  equipo_juridico: 2250000, // COP 22.500
  supervisor_contratos: 2850000, // COP 28.500
});
export const ROLES_GRATUITOS = ['contratista', 'juridico_supervision'];
export const esPlanPago = (rol) => Object.hasOwn(PRECIOS_CENTAVOS, rol);
export const sha256 = (valor) => createHash('sha256').update(valor).digest('hex');

export function vencimientoPrueba(creacion, lanzamiento) {
  return creacion >= lanzamiento ? creacion + 30 * DIA : null;
}

export function sumarMesColombia(inicio) {
  const diferencia = 5 * 3600 * 1000;
  const fecha = new Date(inicio - diferencia);
  const dia = fecha.getUTCDate();
  fecha.setUTCDate(1);
  fecha.setUTCMonth(fecha.getUTCMonth() + 1);
  const ultimo = new Date(Date.UTC(fecha.getUTCFullYear(), fecha.getUTCMonth() + 1, 0));
  fecha.setUTCDate(Math.min(dia, ultimo.getUTCDate()));
  return fecha.getTime() + diferencia;
}

export function validarTransaccion(tx, referencia, correo, centavos) {
  return tx?.status === 'APPROVED' && tx.reference === referencia &&
    tx.currency === 'COP' && tx.amount_in_cents === centavos &&
    (correo == null || tx.customer_email?.trim().toLowerCase() === correo);
}

export function firmaEventoValida(evento, secreto) {
  const campos = evento?.signature?.properties;
  const firma = evento?.signature?.checksum;
  if (!Array.isArray(campos) || campos.length === 0 || campos.length > 20 ||
      !Number.isSafeInteger(evento.timestamp) ||
      typeof firma !== 'string' || !/^[a-f0-9]{64}$/i.test(firma)) return false;
  const valores = campos.map((campo) =>
    typeof campo === 'string' && /^[a-z_]+(?:\.[a-z_]+)+$/i.test(campo)
      ? campo.split('.').reduce((valor, clave) =>
        valor && Object.hasOwn(valor, clave) ? valor[clave] : undefined, evento.data)
      : undefined);
  if (!valores.every((valor) => ['number', 'string', 'boolean'].includes(typeof valor))) return false;
  const esperado = sha256(valores.join('') + evento.timestamp + secreto);
  return timingSafeEqual(Buffer.from(firma, 'hex'), Buffer.from(esperado, 'hex'));
}
