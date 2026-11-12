// Intermediario de solo lectura hacia el directorio de servidores públicos y
// contratistas del SIGEP II (Función Pública), para Contrata Legal.
//
//   GET /api/sigep?q=<nombre>   → página de resultados de la búsqueda
//   GET /api/sigep?hv=<id>      → página de la hoja de vida (p. ej. S2876680-5794-4)
//
// Por qué existe:
// - El navegador no puede consultar el sitio de Función Pública desde la app
//   (no lo permite su política de CORS).
// - Su servidor envía una cadena de certificados incompleta: el certificado
//   del sitio es de Let's Encrypt (emisor YR1) pero lo acompaña un intermedio
//   de Sectigo que no le corresponde. Los navegadores lo resuelven descargando
//   el intermedio; Node no. Aquí se agregan los dos intermedios públicos de
//   Let's Encrypt (YR1 y Root YR firmado por ISRG Root X1) a las raíces de
//   confianza: la verificación TLS sigue completa, no se desactiva.
//
// Solo consulta esas dos direcciones del directorio, quita los datos de
// contacto (correo, teléfono, lugar de nacimiento) y guarda las respuestas
// en caché para no recargar el sitio. La app lee el HTML
// (lib/services/directorio_sigep_service.dart).
import https from 'node:https';
import tls from 'node:tls';

const HOST = 'www.funcionpublica.gov.co';
const BASE = '/dafpIndexerBHV/hvSigep';

// Let's Encrypt YR1 (http://yr1.i.lencr.org/), vence el 2028-09-02.
const LETS_ENCRYPT_YR1 = '-----BEGIN CERTIFICATE-----\nMIIE2zCCAsOgAwIBAgIRAKICU/FfJpHAXcHOE7m8yk4wDQYJKoZIhvcNAQELBQAw\nLjELMAkGA1UEBhMCVVMxDTALBgNVBAoTBElTUkcxEDAOBgNVBAMTB1Jvb3QgWVIw\nHhcNMjUwOTAzMDAwMDAwWhcNMjgwOTAyMjM1OTU5WjAzMQswCQYDVQQGEwJVUzEW\nMBQGA1UEChMNTGV0J3MgRW5jcnlwdDEMMAoGA1UEAxMDWVIxMIIBIjANBgkqhkiG\n9w0BAQEFAAOCAQ8AMIIBCgKCAQEAoVi8X2xCYgMXvJxNPKp/oF13UMgmPABB07VC\nLNDtoXmt9luEZNJSBV10VyT1Pz6LD8Zq1d2gc43WNl1AdRrj4sEnazbOiz0nPpmG\nBp2hui49oZtDIY6wdKeZAi5BbNU20CH6RSBBMLSQ9cXrH8dxdv4PAJ45ssGML68U\nSE3BsjC2a6cAN9L5CgXVIQi5tfNiTPoFZZ3S0OlXqLmmtdV95udWAb5b6e/F49Di\nCsH0Y00Ag72BVIb1hzynmKe+X0mERBTtsb3BwmpV9ipeBjMLoR/D9cHxHQCWoi5l\nTmXwY015J5rGelz1nZjJuxc2kioaX29XJBnhMkP531rSdG5uMwIDAQABo4HuMIHr\nMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDATASBgNVHRMBAf8E\nCDAGAQH/AgEAMB0GA1UdDgQWBBQfLzW+RhSCzUCxrnksVXj699Ro+zAfBgNVHSME\nGDAWgBTe51tg0CJtQCh9Pw0B/qS1UrRRlDAyBggrBgEFBQcBAQQmMCQwIgYIKwYB\nBQUHMAKGFmh0dHA6Ly95ci5pLmxlbmNyLm9yZy8wEwYDVR0gBAwwCjAIBgZngQwB\nAgEwJwYDVR0fBCAwHjAcoBqgGIYWaHR0cDovL3lyLmMubGVuY3Iub3JnLzANBgkq\nhkiG9w0BAQsFAAOCAgEA0+zvMq3kHig1ddTmmm+RibTr9/RpX7k4buanMMRqbV/y\nIvP82zAHN3mvaw+cASuVsdpd0ikjhr4hnhJQLQOzOp2ccKrsdGOAgo0vddeISFAq\nEWEV4lmUM3vFF796up+bSgmJ1u6RupDCMxDgF8M3eLvGuj6L0lu3zkQ0KuQLnKxL\ntB0oQqn1Idg5CuuGpMvQzk29Pa3D/qHurc0EIM9SxukQuJqq63lxsYyRQFU8yMBO\nhq1w5LbfaWNRrz1uklOfI/pYkAb2E2MTZrAMQkBIE2S8Jt1F8gRc96o/xOsrgvSk\na84AisX6xq1lz1Z7jGvrnXc4TMcjxZTjiTaihcYI1JIXZiLtEMSCa5l3cu8YWd6z\ndLRQlqRdclVjuQfNHawRJ6GWlkK0QJosivTKwdBw3KxEtzGo8yMHERbsy57gP1UX\nHOMcmZYQC0gtyR3SxfenIM/MxC3Ia2Ypab/kQ/CTnlIn2KQ5JUC6NYrGCbhFN9bp\n5lKJStEwCUnLpntcrXk5XVDCNv/5RyWpRThkGOV7GetKkQ0qAY8hCzWK6oqnAhDZ\ncjlYVdWfqOw3DIOX6EDNBgAqHarRVxyF9QZdOaXSyPJ0ueD2BYJEBgaCGQ8rAaU/\nQc123V5LTXDZW4CcsPBDyhy4v+c8hClAyw/IkJlfBqxB9D+/wvIMHgECZ4ptP6o=\n-----END CERTIFICATE-----';

// Let's Encrypt Root YR firmado por ISRG Root X1 (http://yr.i.lencr.org/),
// vence el 2032-09-02.
const LETS_ENCRYPT_ROOT_YR = '-----BEGIN CERTIFICATE-----\n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\n-----END CERTIFICATE-----';

const CONFIANZA = [...tls.rootCertificates, LETS_ENCRYPT_YR1, LETS_ENCRYPT_ROOT_YR];

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Max-Age': '86400',
};

// Caché en memoria de la instancia (además de la del CDN de Netlify).
const CACHE = new Map();
const TTL_MS = 6 * 60 * 60 * 1000;
const MAX_CACHE = 300;

function rutaDestino(url) {
  const hv = (url.searchParams.get('hv') || '').trim();
  if (hv) {
    return /^S\d{1,12}-\d{1,8}-\d{1,3}$/.test(hv) ? BASE + '/detallarHV/' + hv : null;
  }
  const consulta = (url.searchParams.get('q') || '')
    .replace(/[^\p{L}\p{N} .'-]/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  if (consulta.length < 3 || consulta.length > 100) return null;
  const parametros = new URLSearchParams({
    find: 'FindNext',
    query: consulta,
    offset: '0',
    max: '30',
  });
  return BASE + '/index?' + parametros.toString();
}

function traer(ruta) {
  return new Promise((resolver, rechazar) => {
    const peticion = https.request(
      {
        host: HOST,
        servername: HOST,
        path: ruta,
        method: 'GET',
        ca: CONFIANZA,
        timeout: 10000,
        headers: {
          'User-Agent': 'ContrataLegal/1.0 (consulta del directorio SIGEP)',
          Accept: 'text/html',
        },
      },
      (respuesta) => {
        if (respuesta.statusCode !== 200) {
          respuesta.resume();
          rechazar(new Error('El directorio respondió ' + respuesta.statusCode));
          return;
        }
        const partes = [];
        let total = 0;
        respuesta.on('data', (parte) => {
          total += parte.length;
          if (total > 3000000) {
            peticion.destroy(new Error('Respuesta demasiado grande'));
            return;
          }
          partes.push(parte);
        });
        respuesta.on('end', () => resolver(Buffer.concat(partes).toString('utf8')));
        respuesta.on('error', rechazar);
      },
    );
    peticion.on('timeout', () => peticion.destroy(new Error('Tiempo agotado')));
    peticion.on('error', rechazar);
    peticion.end();
  });
}

// Quita lo que la app no muestra: scripts, el bloque de contacto de la hoja de
// vida (correo, teléfono, fax, municipio de nacimiento) y la línea de
// contacto de cada resultado de la búsqueda.
function sinContacto(html) {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<div id="datosContacto"[\s\S]*?<\/div>/, '')
    .replace(/<span>[^<]*(?:@|&#64;)[^<]*<\/span>/g, '<span></span>');
}

export default async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS });
  }
  if (req.method !== 'GET') {
    return new Response('Método no permitido', { status: 405, headers: CORS });
  }
  const ruta = rutaDestino(new URL(req.url));
  if (!ruta) {
    return new Response('Consulta no válida', { status: 400, headers: CORS });
  }

  const guardada = CACHE.get(ruta);
  let html = guardada && guardada.vence > Date.now() ? guardada.html : null;
  if (!html) {
    try {
      html = sinContacto(await traer(ruta));
    } catch (error) {
      return new Response('No fue posible consultar el directorio del SIGEP: ' + error.message, {
        status: 502,
        headers: { ...CORS, 'Cache-Control': 'no-store' },
      });
    }
    if (CACHE.size >= MAX_CACHE) CACHE.delete(CACHE.keys().next().value);
    CACHE.set(ruta, { html, vence: Date.now() + TTL_MS });
  }

  // Una hoja de vida inexistente llega como página sin nombre.
  if (ruta.includes('/detallarHV/') && !html.includes('nombre_funcionario')) {
    return new Response('Hoja de vida no encontrada', { status: 404, headers: CORS });
  }

  return new Response(html, {
    status: 200,
    headers: {
      ...CORS,
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
      'Netlify-CDN-Cache-Control': 'public, durable, s-maxage=21600, stale-while-revalidate=86400',
    },
  });
};

export const config = { path: '/api/sigep' };
