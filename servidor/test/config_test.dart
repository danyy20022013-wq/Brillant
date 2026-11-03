import 'package:servidor_brilliant/servidor_brilliant.dart';
import 'package:test/test.dart';

void main() {
  group('Archivo .env', () {
    test('lee CLAVE=valor e ignora comentarios y líneas vacías', () {
      final valores = leerArchivoEnv('''
# comentario

PUERTO=9000
  MODO = desarrollo
ORIGENES_PERMITIDOS="http://a.com,http://b.com"
SIN_IGUAL
=sin_clave
VACIA=
''');
      expect(valores, {
        'PUERTO': '9000',
        'MODO': 'desarrollo',
        'ORIGENES_PERMITIDOS': 'http://a.com,http://b.com',
        'VACIA': '',
      });
    });

    test('acepta fin de línea de Windows', () {
      expect(leerArchivoEnv('A=1\r\nB=2\r\n'), {'A': '1', 'B': '2'});
    });

    test('las variables de entorno tienen prioridad sobre el archivo', () {
      final combinado = combinarEntorno(
        archivo: {'PUERTO': '9000', 'MODO': 'produccion'},
        entorno: {'PUERTO': '7000'},
      );
      expect(combinado, {'PUERTO': '7000', 'MODO': 'produccion'});
    });
  });

  group('Config', () {
    test('valores por defecto: desarrollo en 127.0.0.1:8080', () {
      final config = Config.desde({});
      expect(config.host, '127.0.0.1');
      expect(config.puerto, 8080);
      expect(config.produccion, isFalse);
      expect(config.origenesPermitidos, isEmpty);
    });

    test('lee puerto, modo y orígenes', () {
      final config = Config.desde({
        'PUERTO': '9000',
        'MODO': 'produccion',
        'ORIGENES_PERMITIDOS': ' https://a.com , https://b.com ,',
      });
      expect(config.puerto, 9000);
      expect(config.produccion, isTrue);
      expect(config.origenesPermitidos, ['https://a.com', 'https://b.com']);
    });

    test('un puerto inválido no deja arrancar y explica por qué', () {
      for (final valor in ['abc', '0', '70000']) {
        expect(
          () => Config.desde({'PUERTO': valor}),
          throwsA(
            isA<ConfigException>()
                .having((e) => e.mensaje, 'mensaje', contains('PUERTO')),
          ),
        );
      }
    });

    test('un modo desconocido no deja arrancar', () {
      expect(
        () => Config.desde({'MODO': 'pruebas'}),
        throwsA(isA<ConfigException>()
            .having((e) => e.mensaje, 'mensaje', contains('MODO'))),
      );
    });

    test('producción sin orígenes no deja arrancar', () {
      expect(
        () => Config.desde({'MODO': 'produccion'}),
        throwsA(isA<ConfigException>().having(
            (e) => e.mensaje, 'mensaje', contains('ORIGENES_PERMITIDOS'))),
      );
    });
  });
}
