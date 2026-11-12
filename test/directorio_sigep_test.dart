import 'package:app_secop/widgets/directorio_sigep.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la búsqueda en el SIGEP lleva el nombre en la dirección', () {
    expect(
      DirectorioSigep.busqueda(' fabian alberto cuello redondo ').toString(),
      'https://www.funcionpublica.gov.co/dafpIndexerBHV/hvSigep/index'
      '?find=FindNext&query=fabian+alberto+cuello+redondo',
    );
  });

  test('solo acepta hojas de vida en dominios oficiales', () {
    expect(
      DirectorioSigep.hojaDeVida({
        'url':
            'https://www1.funcionpublica.gov.co/dafpIndexerBHV/hvSigep/detallarHV/S2613307-0018-4',
      })?.host,
      'www1.funcionpublica.gov.co',
    );
    expect(DirectorioSigep.hojaDeVida('https://otro-sitio.com/x'), isNull);
    expect(DirectorioSigep.hojaDeVida(null), isNull);
  });
}
