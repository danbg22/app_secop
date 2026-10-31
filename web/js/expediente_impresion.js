// Ensambla el PDF unificado de un expediente jurídico para impresión:
// por cada documento, una hoja separadora con su nombre seguida de sus páginas.
//
// Se carga bajo demanda desde lib/utils/pdf_unificado_web.dart. Las librerías
// están alojadas en js/vendor (sin CDN) y solo se descargan al usarse:
//   - pdf-lib 1.17.1 (MIT): crea el documento y copia las páginas de los PDF.
//   - pdf.js 4.10.38 (Apache-2.0): solo para PDF cifrados (p. ej. certificados
//     oficiales con restricciones), cuyas páginas pdf-lib no puede copiar; se
//     rasterizan a ~150 ppp.
(function () {
  'use strict';

  var VENDOR = 'js/vendor/';
  var CARTA = [612, 792];
  var AZUL = [0.055, 0.149, 0.275];
  var GRIS = [0.39, 0.45, 0.55];

  var cargas = {};

  function url(ruta) {
    return new URL(ruta, document.baseURI).href;
  }

  // Script clásico (UMD). Oculta un posible `define` AMD mientras carga para
  // que la librería se registre en `window`.
  function cargarScript(ruta) {
    if (!cargas[ruta]) {
      cargas[ruta] = new Promise(function (resolve, reject) {
        var defineAnterior = window.define;
        window.define = undefined;
        var s = document.createElement('script');
        s.src = url(ruta);
        s.async = true;
        s.onload = function () {
          window.define = defineAnterior;
          resolve();
        };
        s.onerror = function () {
          window.define = defineAnterior;
          delete cargas[ruta];
          reject(new Error('No se pudo cargar ' + ruta));
        };
        document.head.appendChild(s);
      });
    }
    return cargas[ruta];
  }

  function pdfLib() {
    return cargarScript(VENDOR + 'pdf-lib-1.17.1/pdf-lib.min.js').then(
      function () {
        return window.PDFLib;
      },
    );
  }

  var pdfJsPromesa = null;
  function pdfJs() {
    if (!pdfJsPromesa) {
      pdfJsPromesa = import(url(VENDOR + 'pdfjs-4.10.38/pdf.min.mjs')).then(
        function (lib) {
          lib.GlobalWorkerOptions.workerSrc = url(
            VENDOR + 'pdfjs-4.10.38/pdf.worker.min.mjs',
          );
          return lib;
        },
        function (e) {
          pdfJsPromesa = null;
          throw e;
        },
      );
    }
    return pdfJsPromesa;
  }

  function hex(buffer) {
    return Array.prototype.map
      .call(new Uint8Array(buffer), function (b) {
        return ('0' + b.toString(16)).slice(-2);
      })
      .join('');
  }

  function canvasAJpg(canvas) {
    return new Promise(function (resolve, reject) {
      canvas.toBlob(
        function (blob) {
          if (!blob) return reject(new Error('canvas vacío'));
          blob.arrayBuffer().then(function (b) {
            resolve(new Uint8Array(b));
          }, reject);
        },
        'image/jpeg',
        0.92,
      );
    });
  }

  // Quita los caracteres que la fuente estándar (WinAnsi) no puede dibujar.
  function limpiarTexto(texto, fuente) {
    var permitidos = new Set(fuente.getCharacterSet());
    return Array.from(String(texto || ''))
      .map(function (c) {
        if (permitidos.has(c.codePointAt(0))) return c;
        return /\s/.test(c) ? ' ' : '';
      })
      .join('')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function partirLineas(texto, fuente, tamano, ancho) {
    var lineas = [];
    var actual = '';
    texto.split(' ').forEach(function (palabra) {
      var prueba = actual ? actual + ' ' + palabra : palabra;
      if (actual && fuente.widthOfTextAtSize(prueba, tamano) > ancho) {
        lineas.push(actual);
        actual = palabra;
      } else {
        actual = prueba;
      }
    });
    if (actual) lineas.push(actual);
    return lineas;
  }

  function dibujarCentrado(pagina, lineas, fuente, tamano, yInicial, color, rgb) {
    var y = yInicial;
    lineas.forEach(function (linea) {
      var w = fuente.widthOfTextAtSize(linea, tamano);
      pagina.drawText(linea, {
        x: (CARTA[0] - w) / 2,
        y: y,
        size: tamano,
        font: fuente,
        color: rgb(color[0], color[1], color[2]),
      });
      y -= tamano * 1.25;
    });
    return y;
  }

  function agregarSeparador(lib, doc, fuentes, item, indice, total) {
    var pagina = doc.addPage(CARTA);
    var ancho = CARTA[0] - 120;
    var titulo =
      limpiarTexto(String(item.titulo).toUpperCase(), fuentes.negrita) ||
      'DOCUMENTO';

    var tamano = 34;
    var lineas = partirLineas(titulo, fuentes.negrita, tamano, ancho);
    while (lineas.length > 4 && tamano > 18) {
      tamano -= 2;
      lineas = partirLineas(titulo, fuentes.negrita, tamano, ancho);
    }

    var altoBloque = lineas.length * tamano * 1.25;
    var y = CARTA[1] / 2 + altoBloque / 2 - tamano;
    y = dibujarCentrado(pagina, lineas, fuentes.negrita, tamano, y, AZUL, lib.rgb);
    y = dibujarCentrado(
      pagina,
      ['Documento ' + indice + ' de ' + total],
      fuentes.normal,
      12,
      y - 14,
      GRIS,
      lib.rgb,
    );

    if (item.nota) {
      var nota = limpiarTexto(item.nota, fuentes.normal);
      dibujarCentrado(
        pagina,
        partirLineas(nota, fuentes.normal, 11, ancho),
        fuentes.normal,
        11,
        y - 18,
        GRIS,
        lib.rgb,
      );
    }
  }

  async function agregarPdf(lib, doc, item) {
    var origen;
    try {
      origen = await lib.PDFDocument.load(item.bytes);
    } catch (e) {
      if (/encrypt/i.test(String(e && (e.message || e.name)))) {
        return agregarPdfRasterizado(doc, item);
      }
      throw new Error(
        'El archivo de "' + item.titulo + '" no es un PDF válido o está dañado.',
      );
    }
    var paginas = await doc.copyPages(origen, origen.getPageIndices());
    paginas.forEach(function (p) {
      doc.addPage(p);
    });
  }

  async function agregarPdfRasterizado(doc, item) {
    var pdfjs = await pdfJs();
    var origen;
    try {
      origen = await pdfjs.getDocument({
        data: item.bytes.slice(),
        isEvalSupported: false,
      }).promise;
    } catch (e) {
      if (e && e.name === 'PasswordException') {
        throw new Error(
          'El PDF de "' +
            item.titulo +
            '" pide contraseña para abrirse. Solicite al contratista una versión sin contraseña.',
        );
      }
      throw new Error('No fue posible leer el PDF de "' + item.titulo + '".');
    }
    try {
      for (var i = 1; i <= origen.numPages; i++) {
        var pagina = await origen.getPage(i);
        var base = pagina.getViewport({ scale: 1 });
        var vista = pagina.getViewport({ scale: 150 / 72 });
        var canvas = document.createElement('canvas');
        canvas.width = Math.ceil(vista.width);
        canvas.height = Math.ceil(vista.height);
        var ctx = canvas.getContext('2d');
        ctx.fillStyle = '#ffffff';
        ctx.fillRect(0, 0, canvas.width, canvas.height);
        await pagina.render({ canvasContext: ctx, viewport: vista }).promise;
        var imagen = await doc.embedJpg(await canvasAJpg(canvas));
        doc
          .addPage([base.width, base.height])
          .drawImage(imagen, { x: 0, y: 0, width: base.width, height: base.height });
        pagina.cleanup();
      }
    } finally {
      await origen.destroy();
    }
  }

  // Toda imagen pasa por canvas: respeta la orientación EXIF de las fotos del
  // celular, admite WEBP y aplana transparencias sobre blanco.
  async function agregarImagen(doc, item) {
    var bitmap;
    try {
      bitmap = await createImageBitmap(new Blob([item.bytes]));
    } catch (e) {
      throw new Error('No fue posible leer la imagen de "' + item.titulo + '".');
    }
    var canvas = document.createElement('canvas');
    canvas.width = bitmap.width;
    canvas.height = bitmap.height;
    var ctx = canvas.getContext('2d');
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(bitmap, 0, 0);
    bitmap.close();

    var imagen = await doc.embedJpg(await canvasAJpg(canvas));
    var margen = 36;
    var escala = Math.min(
      (CARTA[0] - 2 * margen) / imagen.width,
      (CARTA[1] - 2 * margen) / imagen.height,
    );
    var w = imagen.width * escala;
    var h = imagen.height * escala;
    doc.addPage(CARTA).drawImage(imagen, {
      x: (CARTA[0] - w) / 2,
      y: (CARTA[1] - h) / 2,
      width: w,
      height: h,
    });
  }

  // items: [{ titulo, tipo: 'pdf' | 'imagen' | 'sinIncrustar', bytes, sha256, nota }]
  // Nunca rechaza: devuelve { bytes } o { error } con un mensaje para el usuario.
  async function unirExpediente(items, tituloDocumento) {
    try {
      for (var k = 0; k < items.length; k++) {
        var esperado = String(items[k].sha256 || '').toLowerCase();
        if (/^[0-9a-f]{64}$/.test(esperado) && window.crypto && crypto.subtle) {
          var real = hex(await crypto.subtle.digest('SHA-256', items[k].bytes));
          if (real !== esperado) {
            return {
              error:
                'El archivo de "' +
                items[k].titulo +
                '" no coincide con el que se verificó (huella SHA-256 distinta). No se generó el PDF.',
            };
          }
        }
      }

      var lib = await pdfLib();
      var doc = await lib.PDFDocument.create();
      doc.setTitle(String(tituloDocumento || 'Expediente para impresión'));
      doc.setProducer('Contrata Legal');
      doc.setCreator('Contrata Legal');
      var fuentes = {
        negrita: await doc.embedFont(lib.StandardFonts.HelveticaBold),
        normal: await doc.embedFont(lib.StandardFonts.Helvetica),
      };

      for (var i = 0; i < items.length; i++) {
        var item = items[i];
        agregarSeparador(lib, doc, fuentes, item, i + 1, items.length);
        if (item.tipo === 'pdf') {
          await agregarPdf(lib, doc, item);
        } else if (item.tipo === 'imagen') {
          await agregarImagen(doc, item);
        }
      }

      return { bytes: await doc.save() };
    } catch (e) {
      return {
        error: (e && e.message) || 'No fue posible generar el PDF unificado.',
      };
    }
  }

  window.contrataLegalPdf = { unirExpediente: unirExpediente };
})();
