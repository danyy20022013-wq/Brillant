# Servidor de Brilliant

Servidor de cuentas para la app Brilliant, escrito en Dart con `shelf`.
Por ahora tiene configuración, CORS, `GET /salud`, `POST /registro`,
`POST /sesion` y `GET /cuenta`.

## Ejecutar

Desde la carpeta `servidor/`:

```bash
dart pub get
dart run bin/servidor.dart
```

Por defecto escucha en `http://127.0.0.1:8080`. Para comprobarlo:
`GET http://127.0.0.1:8080/salud` responde `{"estado":"ok"}`.

## Configuración

Copia `.env.example` como `.env` (ignorado por git) y ajusta los valores. Las
variables de entorno del sistema tienen prioridad sobre el archivo.

| Variable | Por defecto | Para qué sirve |
|---|---|---|
| `HOST` | `127.0.0.1` | Dirección donde escucha |
| `PUERTO` | `8080` | Puerto |
| `MODO` | `desarrollo` | `desarrollo` o `produccion` |
| `ORIGENES_PERMITIDOS` | vacío | Orígenes del navegador aceptados en producción, separados por comas |
| `RUTA_BASE_DATOS` | `brilliant.db` | Archivo SQLite de las cuentas (ignorado por git) |
| `COSTO_BCRYPT` | `10` | Costo de bcrypt (4 a 15; en producción, al menos 10) |
| `JWT_SECRETO` | (obligatoria) | Clave de al menos 32 bytes para firmar los tokens. Genérala con `dart run bin/generar_secreto.dart` |

## Análisis y pruebas

```bash
dart analyze
dart test
```
