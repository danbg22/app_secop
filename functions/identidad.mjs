import { HttpsError } from 'firebase-functions/v2/https';
import { Timestamp } from 'firebase-admin/firestore';
import { sha256 } from './planes.mjs';

export function cedulaCanonica(valor) {
  if (typeof valor !== 'string' || !/^[\d. -]{5,32}$/.test(valor.trim())) return '';
  const digitos = valor.replace(/\D/g, '');
  return /^\d{5,20}$/.test(digitos) ? digitos : '';
}

export const huellaCedula = (cedula) =>
  sha256(`ContrataLegal::SECOP::AppSec::2026::v1::uniqueness::doc::${cedula}`);

export async function vincularCedula(db, uid, correo, entrada) {
  const nueva = cedulaCanonica(entrada);
  if (entrada != null && !nueva) {
    throw new HttpsError('invalid-argument', 'Escribe una cédula válida de 5 a 20 dígitos.');
  }
  const ref = db.collection('usuarios').doc(uid);
  return db.runTransaction(async (tx) => {
    const perfil = (await tx.get(ref)).data() ?? {};
    const anterior = cedulaCanonica(perfil.documentoNormalizado) || cedulaCanonica(perfil.documento);
    if (nueva && anterior && nueva !== anterior) {
      throw new HttpsError('failed-precondition', 'Usa la cédula que ya figura en tu cuenta. Si necesitas corregirla, contacta a soporte.');
    }
    const cedula = anterior || nueva;
    if (!cedula) return { vinculada: false };
    const indice = db.collection('indices_unicidad').doc(huellaCedula(cedula));
    const reclamo = db.collection('identidades_prueba').doc(sha256(`documento:${cedula}`));
    const [dueno, prueba] = await tx.getAll(indice, reclamo);
    if ((dueno.exists && (dueno.data().uid !== uid || dueno.data().tipo !== 'doc')) ||
        (prueba.exists && prueba.data().uid !== uid)) {
      if (!nueva) return { vinculada: false };
      throw new HttpsError('already-exists', 'Esa cédula ya está registrada en otra cuenta. Inicia sesión con esa cuenta o contacta a soporte.');
    }
    if (!dueno.exists) {
      const historicos = db.collection('usuarios');
      const [normalizados, documentos] = await Promise.all([
        tx.get(historicos.where('documentoNormalizado', '==', cedula).limit(2)),
        tx.get(historicos.where('documento', '==', cedula).limit(2)),
      ]);
      if ([...normalizados.docs, ...documentos.docs].some((otro) => otro.id !== uid)) {
        if (!nueva) return { vinculada: false };
        throw new HttpsError('already-exists', 'Esa cédula ya está vinculada a un registro anterior. Contacta a soporte para recuperar la cuenta.');
      }
    }
    if (!dueno.exists) tx.create(indice, { uid, tipo: 'doc', creado_en: Timestamp.now() });
    if (perfil.cedulaVinculada !== true || perfil.documentoNormalizado !== cedula) {
      tx.set(ref, {
        uid,
        ...(correo && !perfil.email ? { email: correo } : {}),
        documento: perfil.documento || cedula,
        documentoNormalizado: cedula,
        cedulaVinculada: true,
      }, { merge: true });
    }
    return { vinculada: true };
  });
}

// Límite de intentos de vincular una cédula: sin él, se podría probar una
// lista de cédulas para averiguar cuáles ya tienen cuenta.
export const MAX_INTENTOS_CEDULA = 5;
export const VENTANA_INTENTOS_MS = 60 * 60 * 1000;

export function siguienteIntento(registro, ahora) {
  const inicio = registro?.inicio ?? 0;
  const enVentana = ahora - inicio < VENTANA_INTENTOS_MS;
  const usados = enVentana ? registro?.intentos ?? 0 : 0;
  if (usados >= MAX_INTENTOS_CEDULA) return null;
  return { inicio: enVentana ? inicio : ahora, intentos: usados + 1 };
}

export async function registrarIntentoCedula(db, uid, ahora = Date.now()) {
  const ref = db.collection('limites_cedula').doc(uid);
  await db.runTransaction(async (tx) => {
    const siguiente = siguienteIntento((await tx.get(ref)).data(), ahora);
    if (!siguiente) {
      throw new HttpsError('resource-exhausted',
        'Hiciste demasiados intentos con la cédula. Espera una hora e inténtalo de nuevo.');
    }
    tx.set(ref, siguiente);
  });
}

