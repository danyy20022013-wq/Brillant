# Servidor de Brilliant

Servidor de la app Brilliant, escrito en Dart con `shelf`. Permite crear una
cuenta, iniciar sesión, consultar la cuenta y borrarla, y jugar partidas
**multijugador por WebSocket**.

- Las contraseñas se guardan solo como hash **bcrypt**.
- La sesión es un **token JWT HS256** que vence a la hora.
- Las cuentas se guardan en **SQLite**.
- Tiene un **límite de intentos** fallidos y **CORS** para la app web.
- En el multijugador **el servidor es la autoridad**: tira los dados, sortea el
  orden y valida cada jugada con las mismas reglas que la app (el paquete
  [`paquetes/reglas_brilliant`](../paquetes/reglas_brilliant), que ambos usan
  por ruta).

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
| `SEGUNDOS_TURNO` | `60` | Duración de cada turno del multijugador, de 10 a 600 |
| `SEGUNDOS_RECONEXION` | `60` | Plazo para volver a una partida tras caerse, de 10 a 600 |

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

Casi todas las pruebas no abren puertos:

- llaman al servidor en memoria, con SQLite en memoria;
- usan un reloj falso, para probar vencimientos y bloqueos sin esperar;
- usan una clave de prueba falsa y costo de bcrypt 4, para ir rápido;
- el multijugador se prueba con **clientes WebSocket simulados** y un
  programador de tiempo falso (turnos, latidos, caídas y caducidades sin
  esperar), y con semilla fija para los dados.

Solo `test/ruta_ws_test.dart` abre un puerto libre de `127.0.0.1` para probar
`/ws` con un WebSocket real (origen, token y tamaño de los mensajes), y lo
cierra al terminar.

Las reglas del juego tienen sus propias pruebas en
`paquetes/reglas_brilliant` (`dart test` desde esa carpeta).

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
| `GET /ws` | Sí, en el primer mensaje | Conexión WebSocket del multijugador (ver [Multijugador](#multijugador-websocket)) |

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

## Multijugador (WebSocket)

Conexión: `ws://127.0.0.1:8080/ws` (en producción, `wss://` detrás del proxy
HTTPS). Todos los mensajes, en los dos sentidos, son **objetos JSON de texto
con el campo `"tipo"`**, de **4 KB como máximo** (contados en bytes UTF-8).

Las salas y partidas viven **en memoria**: si el servidor se reinicia se
pierden, y la app recibe `sala_no_existe` al intentar volver.

### 1. Conectarse y autenticarse

El token **nunca va en la URL** (quedaría en logs e historiales): va en el
**primer mensaje**.

```json
→ {"tipo": "autenticar", "token": "eyJ…", "sala": "K7M2QX"}
← {"tipo": "autenticado", "usuario": {"id": 1, "nombre": "dany"}, "ultimaAccion": 0, "sala": null}
```

- `sala` es opcional: el código de la sala en la que la app creía estar. Si
  ya no existe, llega además `{"tipo": "sala_no_existe", "codigo": "K7M2QX",
  "mensaje": "…"}`.
- Si el usuario está en una sala, después de `autenticado` llega el `estado`
  completo de esa sala (así se **reconecta**).
- `ultimaAccion` es el último id de acción que el servidor recibió de esa
  cuenta: la app sigue numerando desde ahí.
- **Si no llega en 5 s, o el token es inválido o venció, o el primer mensaje
  es otra cosa**, el servidor cierra con el código `4001` y un motivo
  (`"No llegó el token a tiempo"`, `"Tu sesión no es válida o ya venció"` o
  `"El primer mensaje debe ser autenticar"`).
- **Origen:** si el navegador manda la cabecera `Origin`, debe estar permitido
  con las mismas reglas que CORS; si no, `403` y no se abre el WebSocket. Las
  apps nativas no mandan `Origin` y se autentican igual con el token.

### 2. Latidos

Cada 10 s el servidor manda `{"tipo": "ping"}`. La app responde
`{"tipo": "pong"}` (cualquier mensaje cuenta). Si no responde antes del
siguiente ping, la conexión se da por **caída** y se cierra con `4004`.

### 3. Acciones

Todas las acciones llevan un **`id` entero creciente** por cuenta:

- un id **repetido o viejo** se ignora sin respuesta (reintentos seguros);
- si la acción falla, el error trae el mismo `id`;
- si sale bien, la respuesta es el `estado` difundido a toda la sala.

| `tipo` | Campos | Qué hace |
|---|---|---|
| `crear_sala` | `mapa` (1-4), `maximo` (2-4) | Crea una sala y entra como anfitrión |
| `unirse` | `codigo` | Entra a una sala en lobby (acepta minúsculas) |
| `listo` | `listo` (true/false) | Marca si está listo |
| `salir` | — | Sale del lobby, o de una partida terminada o en la que ya no juega. Responde `{"tipo": "saliste", "codigo": "…"}` |
| `iniciar` | — | Solo el anfitrión, con 2 o más jugadores y todos listos |
| `numeros_iniciales` | `numeros` (6 números) | Sus números iniciales, validados con las reglas del mapa |
| `colocar` | `dadoAncla` (0 o 1), `fila`, `columna` | Coloca el otro dado junto a un número igual al dado ancla |
| `saltar` | — | Descarta la tirada y pasa el turno |
| `rendirse` | — | Deja la partida (la app pide confirmación antes) |

Sin `id`:

| `tipo` | Campos | Qué hace |
|---|---|---|
| `pong` | — | Respuesta al latido |
| `reconectar` | `codigo` | Pide el estado de su sala; si no existe o no es suya, `sala_no_existe` |

Ejemplos:

```json
→ {"tipo": "crear_sala", "id": 1, "mapa": 2, "maximo": 4}
→ {"tipo": "unirse", "id": 1, "codigo": "k7m2qx"}
→ {"tipo": "listo", "id": 2, "listo": true}
→ {"tipo": "numeros_iniciales", "id": 4, "numeros": [1, 2, 3, 4, 5, 6]}
→ {"tipo": "colocar", "id": 5, "dadoAncla": 0, "fila": 0, "columna": 1}
← {"tipo": "error", "codigo": "fuera_de_turno", "mensaje": "No es tu turno", "id": 5}
```

**El cliente nunca elige los dados:** el servidor los tira (con
`Random.secure`) al empezar cada turno y los manda en el estado. `colocar` solo
dice cuál de los dos es el ancla; cualquier otro campo se ignora, y no existe
ningún mensaje para tirar o fijar los dados.

### 4. Estado de la sala

Tras **cada cambio**, todos los miembros conectados reciben el estado
**completo**, con el que la app puede reconstruir todo:

```json
{
  "tipo": "estado",
  "sala": {
    "codigo": "K7M2QX", "mapa": 1, "maximo": 2, "fase": "turnos",
    "anfitrion": 1,
    "jugadores": [
      {"id": 1, "nombre": "dany", "anfitrion": true, "listo": true,
       "enSala": true, "conectado": true, "estado": "jugando",
       "numerosEnviados": true, "tablero": [[null, 5, 1, null, …], …],
       "puntaje": 7, "saltosPorTiempo": 0},
      {"id": 2, "nombre": "ana", "anfitrion": false, "listo": true,
       "enSala": true, "conectado": false, "estado": "jugando", …}
    ],
    "vencenNumeros": null, "segundosParaNumeros": null,
    "orden": [2, 1],
    "turno": {"jugador": 2, "numero": 8, "dados": [3, 5],
              "venceEn": "2026-11-09T12:01:00.000Z", "segundosRestantes": 42},
    "ordenZonas": [[1], [], …],
    "ultimoMovimiento": {"tipo": "colocacion", "jugador": 1, "turno": 7,
      "ancla": 1, "colocado": 1, "fila": 2, "columna": 3, "zona": "Azul 1",
      "zonaCompletada": {"zona": 2, "nombre": "Azul 1", "lugar": 1, "puntos": 7}},
    "resultado": null
  }
}
```

- `fase`: `lobby`, `numeros`, `turnos` o `terminada`.
- En el **lobby** cada jugador trae solo `id`, `nombre`, `anfitrion`, `listo`,
  `enSala` y `conectado`, y la sala trae `caducaEn` y `segundosParaCaducar`.
- `estado` de cada jugador: `jugando`, `rendido` o `abandono`. `enSala` es
  `false` si ya salió de la sala (sigue en la lista para el resultado).
- `tablero` es `null` durante la fase de números: los números de los demás se
  ven al empezar los turnos.
- `ordenZonas`: por cada zona del mapa, los ids de quienes la llenaron, en
  orden (el 1.º, 2.º y 3.º puntúan; del 4.º en adelante no).
- `ultimoMovimiento.tipo`: `colocacion`, `salto`, `tiempo_agotado`,
  `rendicion` o `abandono`.
- `resultado` (al terminar): `[{"id": 1, "posicion": 1, "puntaje": 30,
  "estado": "jugando"}, …]`. Los empates comparten posición (1, 1, 3). Quien
  se rindió o abandonó queda **después de todos los demás sin importar su
  puntaje** (el último en irse queda mejor).

Otros mensajes del servidor:

| `tipo` | Cuándo |
|---|---|
| `sala_cerrada` | La sala se cerró (`"motivo": "caducada"`) |
| `sala_no_existe` | La sala pedida no existe (por ejemplo, tras reiniciar el servidor) |
| `sesion_reemplazada` | La misma cuenta se conectó desde otro lugar; enseguida se cierra con `4002` |
| `error` | `{"codigo": "…", "mensaje": "…", "id": …}` |

### 5. Reglas de las salas

- **Código:** 6 caracteres al azar seguro, sin caracteres ambiguos (sin `0`,
  `O`, `1`, `I` ni `L`).
- **Una sala por usuario.** Quien está en una partida terminada, o se rindió o
  abandonó, sale solo al crear o unirse a otra.
- **Límite para unirse:** 10 intentos por minuto por usuario y 30 por IP
  (frena la adivinación de códigos).
- **Anfitrión:** el primero de la lista. Si sale, pasa al siguiente. Una sala
  vacía se borra.
- **Caducidad:** una sala que no empieza en **15 minutos** se cierra.

### 6. La partida

1. **Números iniciales:** cada jugador manda los suyos y el servidor los valida
   con las reglas (6 números del 1 al 6, sin repetir, respetando la zona de
   cada estrella). A quien no los mande en **90 s** se le asignan unos válidos
   al azar.
2. **Turnos:** el orden se sortea. En cada turno el servidor tira los dados y
   valida el ancla y la casilla con las jugadas posibles. También se puede
   saltar el turno. El servidor lleva el orden de llenado de cada zona y los
   puntos del mapa.
3. **Temporizador:** cada turno dura 60 s (`SEGUNDOS_TURNO`). Si se agota, se
   salta el turno; **tres saltos seguidos por tiempo cuentan como abandono**.
   Jugar o saltar a mano reinicia la cuenta.
4. **Rendirse:** quien se rinde queda último, su tablero se congela y sale del
   orden de turnos. Si tenía el turno, pasa al siguiente.
5. **Fin:** cuando todos los tableros de quienes siguen jugando están llenos, o
   cuando queda un solo jugador (que gana).

### 7. Caídas y reconexión

| Situación | Qué pasa |
|---|---|
| Se cae en el **lobby** | Queda `conectado: false`; si no vuelve en 15 s, sale de la sala |
| Se cae en la **partida** | Queda `conectado: false`; tiene 60 s (`SEGUNDOS_RECONEXION`) para volver con su token y recibir el estado completo. Si no vuelve, `abandono` |
| Era **su turno** | El temporizador del turno sigue corriendo |
| **Misma cuenta, dos conexiones** | La nueva reemplaza a la vieja; la vieja recibe `sesion_reemplazada` y se cierra con `4002` |
| **Nadie conectado** en una partida durante 5 minutos | La sala se cierra |
| **Servidor reiniciado** | Al volver, la app recibe `sala_no_existe` |

### 8. Errores y cierres

**Mensajes mal formados** (no es JSON, falta `tipo` o `id`, tipo desconocido,
más de 4 KB): reciben un `error` y la conexión **sigue abierta**. Con **10 en
un minuto** se cierra con `4003`.

| Código de error | Significado |
|---|---|
| `mensaje_invalido`, `mensaje_muy_grande`, `tipo_desconocido` | Mensaje mal formado |
| `mapa_invalido`, `maximo_invalido` | Datos de `crear_sala` no válidos |
| `sala_inexistente`, `sala_llena`, `sala_iniciada`, `ya_en_sala` | No se pudo unir |
| `demasiados_intentos` | Límite de intentos para unirse |
| `no_en_sala`, `no_eres_anfitrion`, `faltan_jugadores`, `no_todos_listos` | Lobby |
| `fase_incorrecta`, `partida_terminada`, `ya_no_juegas` | La acción no corresponde ahora |
| `numeros_invalidos`, `numeros_ya_enviados` | Números iniciales |
| `fuera_de_turno`, `jugada_invalida` | Turnos |

| Cierre | Motivo |
|---|---|
| `4001` | Sin token a tiempo, token inválido o primer mensaje incorrecto |
| `4002` | Sesión abierta en otra conexión |
| `4003` | Demasiados mensajes no válidos |
| `4004` | No respondió a los latidos |
| `4005` | El servidor se está cerrando |

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

- **Multijugador:**
  - el token va en el primer mensaje, nunca en la URL, y no se registra;
  - se verifica el `Origin` de los navegadores;
  - los dados, el orden y los números al azar usan `Random.secure`;
  - cada jugada se valida en el servidor con las reglas compartidas;
  - los mensajes se limitan a 4 KB. Ojo: `dart:io` recibe el mensaje entero
    antes de que el servidor pueda medirlo, así que un proxy delante debería
    limitar también el tamaño de los mensajes.
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
   - El proxy también debe reenviar el WebSocket de `/ws` (cabeceras
     `Upgrade` y `Connection`); la app se conecta con `wss://`.
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
