# Servidor de Brilliant

Servidor de cuentas de la app Brilliant, escrito en Dart con `shelf`. Permite
crear una cuenta, iniciar sesión, consultar la cuenta y borrarla.

- Las contraseñas se guardan solo como hash **bcrypt**.
- La sesión es un **token JWT HS256** que vence a la hora.
- Las cuentas se guardan en **SQLite**.
- Tiene un **límite de intentos** fallidos y **CORS** para la app web.

## Instalación

Hace falta Dart 3.11 o superior (se probó con Dart 3.13 en Windows). Desde la
carpeta `servidor/`:

```bash
dart pub get
```

No hay que instalar nada más:

- **`sqlite3`** trae SQLite incluido y lo prepara la primera vez con
  *build hooks* (verás "Running build hooks…").
- **`bcrypt`** está escrito solo en Dart.

## Configuración

1. Copia `.env.example` como `.env`. El `.env` está ignorado por git: nunca lo
   subas.
2. Genera la clave de los tokens y pégala en `JWT_SECRETO`:

   ```bash
   dart run bin/generar_secreto.dart
   ```

Las variables de entorno del sistema tienen prioridad sobre el archivo `.env`.
Si falta algo obligatorio o un valor no es válido, el servidor no arranca y
explica por qué (código de salida 78).

| Variable | Por defecto | Para qué sirve |
|---|---|---|
| `JWT_SECRETO` | **obligatoria** | Clave para firmar los tokens, de al menos 32 bytes |
| `HOST` | `127.0.0.1` | Dirección donde escucha |
| `PUERTO` | `8080` | Puerto |
| `MODO` | `desarrollo` | `desarrollo` o `produccion` |
| `ORIGENES_PERMITIDOS` | vacío | Orígenes aceptados en producción, separados por comas (obligatorio en producción) |
| `RUTA_BASE_DATOS` | `brilliant.db` | Archivo SQLite de las cuentas (los `*.db` están ignorados por git) |
| `COSTO_BCRYPT` | `10` | Costo de bcrypt, de 4 a 15 (en producción, al menos 10) |

### CORS

- **En `desarrollo`** se acepta la app desde cualquier puerto de
  `http://localhost` y `http://127.0.0.1`, porque `flutter run -d chrome` usa
  un puerto al azar.
- **En `produccion`** solo se aceptan los orígenes exactos de
  `ORIGENES_PERMITIDOS`.
- Las preguntas previas (`OPTIONS`) de un origen permitido reciben 204 con las
  cabeceras CORS; las de un origen no permitido, 403.

### Costo de bcrypt

Cada +1 duplica el tiempo de crear la cuenta y de iniciar sesión. En el equipo
de desarrollo, con Windows, `dart run` y el equipo bajo carga, se midió:

- **costo 10:** unos 200 ms en promedio, pero entre 124 y 757 ms;
- **costo 11:** más de 500 ms, y casi siempre más de un segundo.

Por eso el valor por defecto es 10. Si tu equipo es más rápido, prueba con 11.
El hash se calcula en otro isolate para no frenar las demás peticiones.

## Ejecutar

```bash
dart run bin/servidor.dart
```

Muestra `Servidor de Brilliant escuchando en http://127.0.0.1:8080
(desarrollo)` y una línea por petición (método, ruta, estado y tiempo).
**Nunca registra cabeceras ni cuerpos**, así que no escribe contraseñas ni
tokens. Se cierra con Ctrl+C.

## Análisis y pruebas

```bash
dart analyze
dart test
```

Las pruebas no abren puertos:

- llaman al servidor en memoria, con SQLite en memoria;
- usan un reloj falso, para probar vencimientos y bloqueos sin esperar;
- usan una clave de prueba falsa y costo de bcrypt 4, para ir rápido.

## Endpoints

Todas las respuestas son JSON. Los errores tienen la forma
`{"error": "mensaje en español"}` y nunca incluyen detalles internos.

| Método y ruta | Necesita token | Qué hace |
|---|---|---|
| `GET /salud` | No | Comprueba que el servidor está vivo |
| `POST /registro` | No | Crea una cuenta |
| `POST /sesion` | No | Inicia sesión y entrega un token |
| `GET /cuenta` | Sí | Devuelve la cuenta del token (sirve para restaurar la sesión) |
| `DELETE /cuenta` | Sí | Borra la cuenta del token, pidiendo otra vez la contraseña |

Los ejemplos usan `curl` (en Windows viene como `curl.exe`) y salieron de una
ejecución real.

### `GET /salud`

```bash
curl http://127.0.0.1:8080/salud
```
`200` → `{"estado":"ok"}`

### `POST /registro`

```bash
curl -H "Content-Type: application/json" \
  -d '{"nombre":"dany","correo":"dany@correo.com","contrasena":"secreta1"}' \
  http://127.0.0.1:8080/registro
```

| Estado | Respuesta |
|---|---|
| `201` | `{"usuario":{"id":1,"nombre":"dany","correo":"dany@correo.com"}}` |
| `400` | Datos inválidos, con el mismo mensaje que la app (por ejemplo `"Mínimo 6 caracteres"` o `"Máximo 72 bytes (las tildes y la ñ ocupan 2)"`) |
| `409` | `"Ese correo ya está registrado"` o `"Ese nombre de usuario ya está en uso"` |
| `413` | Cuerpo de más de 16 KB |
| `429` | Demasiados registros desde esa IP |

- **Reglas:** nombre de 3 a 16 letras, números o `_`; correo válido;
  contraseña de 6 caracteres a 72 bytes en UTF-8.
- **Unicidad:** el correo y el nombre son únicos sin distinguir mayúsculas.
- **Sin token:** el registro no entrega token; la app inicia sesión después
  con `POST /sesion`.

### `POST /sesion`

```bash
curl -H "Content-Type: application/json" \
  -d '{"correo":"dany@correo.com","contrasena":"secreta1"}' \
  http://127.0.0.1:8080/sesion
```

| Estado | Respuesta |
|---|---|
| `200` | `{"token":"eyJ…","expiraEn":"2026-11-03T13:00:00.000Z","usuario":{…}}` |
| `400` | `"Datos inválidos"` (falta el correo o la contraseña) |
| `401` | `"Correo o contraseña incorrectos"`: **el mismo mensaje** si el correo no existe o si la contraseña está mal, y con un tiempo parecido |
| `429` | `"Demasiados intentos. Prueba de nuevo en N minutos."` con la cabecera `Retry-After` en segundos |

### `GET /cuenta`

```bash
curl -H "Authorization: Bearer <token>" http://127.0.0.1:8080/cuenta
```

| Estado | Respuesta |
|---|---|
| `200` | `{"usuario":{"id":1,"nombre":"dany","correo":"dany@correo.com"}}` |
| `401` | `"Tu sesión no es válida o ya venció"`, con `WWW-Authenticate: Bearer` |

### `DELETE /cuenta`

```bash
curl -X DELETE -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token>" \
  -d '{"contrasena":"secreta1"}' \
  http://127.0.0.1:8080/cuenta
```

| Estado | Respuesta |
|---|---|
| `204` | Sin cuerpo: la cuenta se borró |
| `400` | `"Datos inválidos"` (falta la contraseña) |
| `401` | Token ausente, inválido o vencido |
| `403` | `"La contraseña no es correcta"` |
| `429` | 5 contraseñas incorrectas en 15 minutos para esa cuenta |

Después de borrar, los tokens de esa cuenta dejan de servir: en cada petición
se comprueba que la cuenta exista. Los ids nunca se reutilizan, así que un
token viejo tampoco sirve para una cuenta nueva con los mismos datos.

## Seguridad

- **Contraseñas:**
  - bcrypt con sal aleatoria (`Random.secure`);
  - nunca se guardan ni se registran en texto;
  - el servidor vuelve a validar las mismas reglas que la app.
- **Tokens JWT:**
  - HS256 con `JWT_SECRETO`; llevan solo `sub` (id), `iat` y `exp`, y vencen a
    la hora;
  - el servidor exige `alg: HS256` y `typ: JWT` antes de verificar, así que
    rechaza `alg: none`, otros algoritmos y otras claves;
  - exige que el token tenga `exp`;
  - comprueba el vencimiento con su propio reloj.
- **No revelar qué correos existen:**
  - el inicio de sesión responde igual y tarda lo mismo: si el correo no
    existe, compara contra un hash de relleno;
  - **el registro sí lo revela** ("Ese correo ya está registrado"). Evitarlo
    exige verificar el correo por email, y eso no está implementado; el límite
    por IP lo frena.
- **Límite de intentos:**
  - **`/sesion`:** 5 fallos en 15 minutos por correo y por IP. Un inicio de
    sesión correcto reinicia el contador de ese correo.
  - **`/registro`:** 5 intentos en 15 minutos por IP.
  - **`DELETE /cuenta`:** 5 contraseñas incorrectas por cuenta.

  > ⚠️ El contador vive **en memoria**: se pierde al reiniciar el servidor y
  > **solo sirve con una instancia**. Con varias instancias hace falta un
  > almacén compartido (por ejemplo Redis).

- **SQL:** todas las consultas usan parámetros, nunca texto armado a mano.
- **Errores:** un error inesperado responde 500 con `"Error interno del
  servidor"` y solo registra el tipo de error.

## Despliegue real: HTTPS y proxy inverso

Este servidor habla **HTTP sin cifrar**. Eso vale en desarrollo, en tu propio
equipo. En un despliegue real:

1. **HTTPS:**
   - Pon delante un **proxy inverso** (por ejemplo Caddy o nginx) o usa el
     HTTPS de tu hosting.
   - El proxy tiene el certificado TLS y reenvía las peticiones al servidor
     Dart, que escucha solo en la red interna (`HOST=127.0.0.1`).
   - Activa en el proxy la cabecera `Strict-Transport-Security` (HSTS).
2. **Modo producción:** usa `MODO=produccion` y `ORIGENES_PERMITIDOS` con la
   dirección real de la app (por ejemplo `https://brilliant.ejemplo.com`).
3. **Claves:**
   - `JWT_SECRETO` va en el gestor de secretos o en las variables de entorno
     del hosting, nunca en el repositorio.
   - Si se filtra, cámbiala: todos los tokens dejan de valer.
4. **IP real:**
   - Detrás de un proxy, la IP que ve el servidor es la del proxy, así que el
     límite por IP contaría a todos juntos.
   - Habría que leer `X-Forwarded-For`, pero solo si viene de tu proxy. Eso
     todavía no está implementado.
5. **Base de datos:** haz copias de seguridad del archivo SQLite y guárdalo
   fuera de la carpeta pública.
