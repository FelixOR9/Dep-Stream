# Dep-Stream — Arquitectura

**Versión:** 0.1.0+1 — Etapa 0: Fundación.

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
    database/               AppDatabase, SQLite v1.
  features/
    home/                   Lista de partidos.
    match/                  MatchSession, MatchRepository, crear partido.
    settings/               Versión y estado real de los permisos.
android/app/src/main/kotlin/com/felix/depstream/
  MainActivity.kt           Canal de permisos + canal de notificación.
  permissions/              PermissionManager + PermissionStateResolver.
  stream/                   DepStreamForegroundService (preparación).
```

## Datos

- **SQLite v1**, tabla `matches` (`id`, `home_team`, `away_team`,
  `created_at`, `status`). Estado actual: solo `draft`.
- Las migraciones futuras serán versionadas (v1 → v2…) y nunca borrarán
  datos sin autorización.
- El estado de los permisos **nunca** se guarda en SQLite. El historial
  de "ya se pidió antes" vive en SharedPreferences
  (`depstream_permission_history`) y solo sirve para distinguir la
  primera petición de la negación permanente.

## Permisos

Estados: `notRequested` / `granted` / `denied` / `permanentlyDenied`.
Se comprueban en cada llamada y al volver a la app (onResume). El canal
de plataforma es `com.felix.depstream/permissions` con los métodos
`checkPermissions`, `requestPermissions` y `openAppSettings`.

## Dónde irá lo que falta

| Función futura | Dónde irá | Etapa |
|---|---|---|
| Marcador y reloj del partido | `features/match/` (MatchSession + MatchClock) | 1 |
| Cámara y vista previa | Kotlin Camera2 + overlay en Flutter | 2 |
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
`depstream_general`. **Nunca se arranca en la Etapa 0** y nunca muestra
una notificación de "Grabando" sin estar grabando.

## Firma y CI

- Workflow `.github/workflows/flutter-ci.yml`: `flutter analyze`,
  `flutter test`, pruebas Kotlin, `flutter build apk --debug`, artefacto
  7 días. El archivo lo crea Félix desde la web de GitHub (la API no
  permite crearlo).
- Firma estable de depuración con keystore dedicado
  (alias `depstreamdebug`), restaurado en CI desde secretos. Todos los
  APK debug usan la misma firma y se instalan como actualización.
