# Servidor de Brilliant

Servidor de cuentas para la app Brilliant, escrito en Dart con `shelf`.
Por ahora solo tiene la base: configuración, CORS y `GET /salud`.

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

## Análisis y pruebas

```bash
dart analyze
dart test
```
