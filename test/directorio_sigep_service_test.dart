import 'package:app_secop/services/directorio_sigep_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Páginas sintéticas con la estructura del directorio del SIGEP (datos
// inventados). La de búsqueda ya pasó por el intermediario: la línea de
// contacto llega vacía.
const _busqueda = '''
<table class="table table-striped table-hover"><tbody>
  <tr class="odd">
    <!--<td class="center-text columna-foto"></td>-->
    <td class="columna-datos">
      <span>
        <!--<a href="https://www.funcionpublica.gov.co/web/sigep2/hdv/-/directorio/S111-22-3/view"></a>-->
        <a href="/dafpIndexerBHV/hvSigep/detallarHV/S111-22-3" target="_blank">
          ANA MARÍA PÉREZ GÓMEZ
          <img class="leyenda-tipoFuncionario-busqueda" src="x.png" title="Servidor">
        </a>
      </span>
      <br/><span>
        Servidor Público
      </span>
      <br/><span>
        ALCALDIA DE EJEMPLO - CESAR
      </span>
      <br/><span></span><br/>
    </td>
  </tr>
  <tr class="even">
    <td class="columna-datos">
      <span><a href="/dafpIndexerBHV/hvSigep/detallarHV/S444-55-6">Luis Ortega &amp; Hijos</a></span>
      <br/><span>Contratista</span><br/><span>SERVICIO NACIONAL DE APRENDIZAJE</span>
    </td>
  </tr>
  <tr><td class="columna-datos"><span><a href="/otra/ruta">sin enlace válido</a></span></td></tr>
</tbody></table>
''';

const _hoja = '''
<div class="header_directorio_detail">
  <p class="nombre_funcionario">ANA MARÍA PÉREZ GÓMEZ</p>
  <p class="cargo_funcionario">
        PROFESIONAL UNIVERSITARIO
  </p>
  <p class="institucion_funcionario">ALCALDIA DE EJEMPLO</p>
  <p class="dependencia_funcionario">SECRETARÍA DE HACIENDA</p>
</div>
<div id="formacionAcademica" class="w-100 mt-2">
  <h2><span class="directorio_subtitulo">Formación Académica</span></h2>
  <ul>
    <li class="ml-4">PROFESIONAL
        - CONTADURÍA PÚBLICA
            - Graduado</li>
    <li class="ml-4">ESPECIALIZACION - FINANZAS PÚBLICAS - Graduado</li>
  </ul>
</div>
<div id="experienciaLaboral" class="w-100 mt-2">
  <table class="directorio_tabla">
    <thead><tr><th>Cargos</th><th>Entidad</th><th>Fecha Inicio</th><th>Fecha Fin</th></tr></thead>
    <tbody>
      <tr>
        <td class="text-left directorio_td_data">PROFESIONAL UNIVERSITARIO</td>
        <td class="text-left directorio_td_data">ALCALDIA DE EJEMPLO</td>
        <td class="directorio_td_data">08/04/2019</td>
        <td class="directorio_td_data">Actual</td>
      </tr>
      <tr>
        <td class="text-left directorio_td_data">CONTRATISTA</td>
        <td class="text-left directorio_td_data">EMPRESA &amp; CÍA</td>
        <td class="directorio_td_data">01/02/2016</td>
        <td class="directorio_td_data">15/11/2018</td>
      </tr>
    </tbody>
  </table>
</div>
<div id="escalaSalarial" class="w-100 mt-2"><table><tbody><tr><td>no</td><td>es</td><td>experiencia</td><td>x</td></tr></tbody></table></div>
''';

void main() {
  test('lee las filas de la búsqueda (nombre, tipo, entidad)', () {
    final r = DirectorioSigepService.leerBusqueda(_busqueda);
    expect(r, hasLength(2));
    expect(r[0].id, 'S111-22-3');
    expect(r[0].nombre, 'ANA MARÍA PÉREZ GÓMEZ');
    expect(r[0].tipo, 'Servidor Público');
    expect(r[0].esServidorPublico, isTrue);
    expect(r[0].entidad, 'ALCALDIA DE EJEMPLO · CESAR');
    expect(r[1].nombre, 'Luis Ortega & Hijos');
    expect(r[1].esServidorPublico, isFalse);
  });

  test('lee la hoja de vida sin mezclar otras tablas', () {
    final h = DirectorioSigepService.leerHojaDeVida(_hoja, 'S111-22-3')!;
    expect(h.nombre, 'ANA MARÍA PÉREZ GÓMEZ');
    expect(h.cargo, 'PROFESIONAL UNIVERSITARIO');
    expect(h.entidad, 'ALCALDIA DE EJEMPLO');
    expect(h.dependencia, 'SECRETARÍA DE HACIENDA');
    expect(h.formacion, [
      'PROFESIONAL · CONTADURÍA PÚBLICA · Graduado',
      'ESPECIALIZACION · FINANZAS PÚBLICAS · Graduado',
    ]);
    expect(h.experiencia, hasLength(2));
    expect(h.experiencia.first.fin, 'Actual');
    expect(h.experiencia.last.entidad, 'EMPRESA & CÍA');
    expect(
      h.enlace.toString(),
      'https://www.funcionpublica.gov.co/dafpIndexerBHV/hvSigep/detallarHV/S111-22-3',
    );
  });

  test('una página sin nombre no es una hoja de vida', () {
    expect(
      DirectorioSigepService.leerHojaDeVida('<html></html>', 'S1-1-1'),
      isNull,
    );
  });

  test('texto: sin etiquetas, comentarios ni entidades', () {
    expect(
      DirectorioSigepService.texto(
        '<b>A&#64;b</b> <!-- x --> &aacute; &nbsp; c',
      ),
      'A@b á c',
    );
  });

  test('sin intermediario configurado no consulta nada', () async {
    expect(DirectorioSigepService.disponible, isFalse);
    expect(await DirectorioSigepService.buscar('ana pérez'), isEmpty);
    expect(await DirectorioSigepService.hojaDeVida('S111-22-3'), isNull);
  });
}
