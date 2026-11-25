# Dep-Stream — Arquitectura

**Versión:** 0.3.0+3 — Etapa 2: Cámara y overlay.

## Principios

- **Android primero, un solo teléfono.** Sin iOS en esta etapa.
- **`MatchSession` es la única fuente de verdad del partido.** Nada de
  duplicar equipos, fecha o estado en dos sitios.
- **Sin botones muertos, sin código ficticio.** Si una función no está
  implementada, no se muestra como si lo estuviera.
- **Sin secretos en el repo.** Claves y tokens solo en almacenamiento
  seguro del teléfono y en secretos de GitHub Actions.

## Estructura

```
lib/
  main.dart                 Arranque: abre la base de datos y muestra la app.
  app.dart                  MaterialApp, tema y rutas.
  core/
    brand/brand_mark.dart   Marca Dep-Stream (reutilizable para el icono).
    theme/app_theme.dart    Tema oscuro propio.
    permissions/            Estados de permiso y puente Dart ↔ Kotlin.
    storage/                SecureCredentialStore (claves futuras).
    database/               AppDatabase, SQLite v2 + migración v1 → v2.
  features/
    home/                   Lista de partidos (con marcador y estado).
    match/                  MatchSession, MatchEvent, MatchClock,
                            MatchController, MatchRepository, crear partido
                            y pantalla de partido en vivo.
    camera/                 CameraService, CameraController,
                            CameraOverlayData, overlay y pantalla de cámara.
    settings/               Versión y estado real de los permisos.
android/app/src/main/kotlin/com/felix/depstream/
  MainActivity.kt           Canal de permisos + canal de cámara + canal
                            de notificación.
  permissions/              PermissionManager + PermissionStateResolver.
  camera/                   CameraPreviewController (sesión Camera2) +
                            CameraPreviewMath (tamaño y rotación, puros).
  stream/                   DepStreamForegroundService (preparación).
```

## Datos

- **SQLite v2**, tabla `matches` (`id`, `home_team`, `away_team`,
  `created_at`, `status`, `home_color`, `away_color`,
  `period_duration_minutes`, `periods_count`, `home_score`, `away_score`,
  `current_period`, `clock_status`, `clock_started_at`,
  `clock_accumulated_ms`, `updated_at`) y tabla `match_events` (`id`,
  `match_id`, `team`, `kind`, `minute`, `created_at`).
- Estados del partido: `draft` → `inProgress` → `paused` →
  `periodEnded` → `finished` (terminal). Solo se edita en `draft`.
- El marcador es un caché de los eventos de gol: marcador y evento se
  escriben siempre en la misma transacción. El botón −1 anula el gol más
  reciente del equipo.
- El reloj es hora de pared (`MatchClock`, Dart puro): `elapsed =
  accumulated + (ahora − startedAt)` mientras corre. Al cargar, si el
  tiempo superó la duración del periodo, se congela en fin de periodo.
  Si Félix cambia la hora del teléfono a mano en mitad de un partido,
  el reloj saltará: limitación conocida, mismo diseño que TRANSMITI2.
- La migración v1 → v2 solo usa `ADD COLUMN` con `DEFAULT` + la tabla
  nueva, y un backfill de `updated_at = created_at`. Nunca borra datos.
  Una base migrada y una base nueva en v2 tienen el mismo esquema (hay
  test que lo comprueba).
- El estado de los permisos **nunca** se guarda en SQLite. El historial
  de "ya se pidió antes" vive en SharedPreferences
  (`depstream_permission_history`) y solo sirve para distinguir la
  primera petición de la negación permanente.

## Permisos

Estados: `notRequested` / `granted` / `denied` / `permanentlyDenied`.
Se comprueban en cada llamada y al volver a la app (onResume). El canal
de plataforma es `com.felix.depstream/permissions` con los métodos
`checkPermissions`, `requestPermissions`, `requestCamera` (solo cámara,
Etapa 2) y `openAppSettings`.

## Cámara y overlay (Etapa 2)

- **Camera2 nativa en Kotlin, sin plugins.** `CameraPreviewController`
  es dueño de la sesión: elige la cámara trasera, el tamaño 1280x720
  (o el 16:9 más cercano por debajo, nunca uno inventado), abre en un
  hilo propio (`DepStreamCamera`), crea la sesión con la superficie de
  la textura y pide repetición con autoenfoque continuo. El cierre es
  ordenado siempre (sesión → dispositivo → hilo), también si la
  apertura falló a medias.
- La vista previa llega a Flutter por `TextureRegistry`: el canal
  `com.felix.depstream/camera` (`openCamera` → `textureId`,
  `closeCamera`, `getCameraState`) y el widget es un `Texture` en
  `AspectRatio(16/9)`. Sin audio en esta etapa.
- **Overlay 1280x720, un solo diseño fijo.** `CameraOverlayData` (Dart
  puro, desde `MatchSession`) alimenta el dibujo: barra superior con
  equipos y marcador, reloj `MM:SS` + periodo + estado, franja de
  patrocinadores con el texto "Dep-Stream" (sin logos; Etapa 6). Los
  tamaños escalan con el ancho del lienzo (a 1280, marcador 64 px y
  reloj 48 px). El overlay se alimenta del mismo `MatchController` que
  la pantalla de partido: no hay una segunda fuente de datos.
- **Pantalla de cámara** (`'/camera'`): horizontal fija mientras está
  abierta, visor a la izquierda y controles a la derecha (gol +1 por
  equipo con el color del equipo, pausa/reanudar, volver al partido).
  Tarjetas, −1, fin de periodo y finalizar se quedan en la pantalla de
  partido. La cámara se abre al entrar, se cierra al salir y al pasar
  a segundo plano, y se reabre al volver. Si está denegada, pantalla
  honesta (pedir permiso / abrir ajustes / volver); el partido nunca
  depende de la cámara.
- **Orientación:** el sensor está a 90°; la textura se gira según la
  rotación de la pantalla (fórmula estándar de Camera2, probada con
  unitarios). El giro lo aplica el widget `Texture` en Dart
  (`RotatedBox` en `CameraPreviewWidget`): en Kotlin no se puede,
  `SurfaceTexture` no tiene `setTransform`. La pantalla se bloquea en
  horizontal, así que el giro es fijo mientras está abierta.
- **Tamaños en orientación del sensor:** `getOutputSizes` devuelve los
  tamaños traspuestos respecto a la pantalla (el 1280x720 aparece como
  720x1280 con sensor a 90°). La selección se hace en orientación de
  pantalla (`toDisplayOrientation`) y el búfer se pide en orientación
  del sensor (`toSensorOrientation`, 720x1280); elegir directo de la
  lista caía al 4:3 más grande y el visor 16:9 lo estiraba (imagen
  distorsionada, fix Etapa 2, con unitarios que simulan la lista real
  del S24 Ultra).
- La selección de tamaño y la rotación viven en `CameraPreviewMath`
  (lógica pura, probada con JUnit) porque las clases del framework de
  Android no se pueden usar en tests unitarios.

## Dónde irá lo que falta

| Función futura | Dónde irá | Etapa |
|---|---|---|
| Marcador y reloj del partido | `features/match/` (MatchSession + MatchClock) | 1 ✓ |
| Cámara y vista previa | Kotlin Camera2 + overlay en Flutter | 2 ✓ |
| Grabación local MP4 | Kotlin MediaCodec/MediaMuxer + `stream/` | 3 |
| Biblioteca de grabaciones | `features/library/` (nueva) | 4 |
| Facebook Live manual (RTMP) | Proveedor de streaming separado del motor de video | 5 |
| Jugadores y patrocinadores | `features/match/` (eventos y overlay) | 6 |
| Repeticiones | Buffer de momentos + `features/library/` | 7 |
| Control remoto del marcador | `features/remote/` (nueva) | 8 |
| Facebook Login / Graph API | Proveedor de streaming (sin romper lo manual) | 10 |
| Cuenta y PRO | `features/account/` (nueva) | 11 |

El proveedor de streaming irá **separado** del motor de video: un solo
codificador, varios destinos posibles. El método manual seguirá
funcionando aunque se añada el automático.

## Foreground Service

En la Etapa 0 solo hay preparación: el servicio está registrado en el
`AndroidManifest` con `foregroundServiceType="camera|microphone"`, existe
la clase `DepStreamForegroundService` y se crea el canal de notificación
`depstream_general`. **Nunca se arranca en las Etapas 0, 1 ni 2** y nunca
muestra una notificación de "Grabando" sin estar grabando. Se arranca
en la Etapa 3 (grabación) y la Etapa 5 (vivo).

## Firma y CI

- Workflow `.github/workflows/flutter-ci.yml`: `flutter analyze`,
  `flutter test`, pruebas Kotlin, `flutter build apk --debug`, artefacto
  7 días. El archivo lo crea Félix desde la web de GitHub (la API no
  permite crearlo).
- Firma estable de depuración con keystore dedicado
  (alias `depstreamdebug`), restaurado en CI desde secretos. Todos los
  APK debug usan la misma firma y se instalan como actualización.
