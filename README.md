# Dep-Stream

Transmite partidos de fútbol en vivo a Facebook desde tu teléfono, con
marcador y grabación local.

**Estado: Etapa 0 — Fundación (v0.1.0+1).** La app instala, abre, crea
partidos y los guarda en el teléfono. Todavía NO hay cámara, grabación,
transmisión ni marcador: eso llega en las siguientes etapas.

## Qué hace hoy

- Pantalla principal con la lista de partidos guardados.
- Crear un partido (equipo local, equipo visitante, fecha) y guardarlo en
  SQLite. Los datos sobreviven al cerrar la app y al reiniciar el teléfono.
- Ajustes: versión de la app y estado real de los permisos de cámara,
  micrófono y notificaciones, con botón para pedirlos y para abrir los
  ajustes del sistema si alguno está negado para siempre.
- Base de datos local v1 y almacenamiento seguro preparado para las claves
  de transmisión (Etapa 5). No hay ninguna clave guardada.

## Qué NO hace todavía

Cámara, vista previa, grabación, RTMP, Facebook Live, marcador, reloj,
jugadores, cuentas ni pagos. Ver `docs/ARQUITECTURA.md` para saber dónde
irá cada cosa.

## Cómo compilar

Requisitos: Flutter 3.50.0, Java 17, Android SDK 36.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

El APK queda en `build/app/outputs/flutter-apk/app-debug.apk`.

## Firma estable

Los APK de depuración se firman siempre con el mismo keystore dedicado
(alias `depstreamdebug`). Así cada APK nuevo se instala sobre el anterior
sin desinstalar. El keystore NO está en el repo: en CI se restaura desde
el secreto `DEPSTREAM_DEBUG_KEYSTORE_BASE64` y las credenciales llegan
por secretos de GitHub Actions. Nunca se escriben claves en el código.

## Estructura

Ver `docs/ARQUITECTURA.md`.

## Reglas del proyecto

- Etapas independientes: no se avanza a la siguiente sin autorización
  expresa de Félix.
- Nada se declara funcionando sin probarlo en el teléfono (Samsung S24 Ultra).
- Sin botones muertos, sin código ficticio, sin secretos en el repo.
