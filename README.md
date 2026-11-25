# Dep-Stream

Transmite partidos de fútbol en vivo a Facebook desde tu teléfono, con
marcador y grabación local.

**Estado: Etapa 2 — Cámara y overlay (v0.3.0+3).** La app crea partidos
con equipos, colores, duración y periodos, y los juega: marcador grande,
reloj de pared, goles +1/−1 y tarjetas, todo guardado en el teléfono.
Desde un partido se abre la cámara trasera con el marcador encima
(overlay 1280x720) y se puede marcar un gol o pausar sin salir de la
cámara. Todavía NO hay grabación ni transmisión: eso llega en las
siguientes etapas.

## Qué hace hoy

- Pantalla principal con la lista de partidos guardados, con marcador y
  estado de cada uno. Tocar un partido abre su pantalla en vivo.
- Crear un partido (equipos, colores, duración del periodo, número de
  periodos, fecha) y editarlo mientras siga en borrador.
- Pantalla de partido: marcador grande, reloj `MM:SS` con hora de pared
  (sigue correcto al cerrar la app, dejarla en segundo plano o reiniciar
  el teléfono), botones de gol +1/−1 con confirmación para anular,
  tarjetas amarillas y rojas, pausa, reanudación, fin de periodo y
  finalización con confirmación. Cada gol y cada tarjeta se guarda como
  evento con su minuto; el marcador nunca se desincroniza de los eventos.
- Ajustes: versión de la app y estado real de los permisos de cámara,
  micrófono y notificaciones, con botón para pedirlos y para abrir los
  ajustes del sistema si alguno está negado para siempre.
- Cámara (Camera2 nativa, sin plugins): vista previa 1280x720 con el
  overlay del partido encima (equipos y colores, marcador, reloj,
  periodo, estado), en horizontal fija y con controles grandes para una
  mano (gol +1 por equipo, pausa/reanudar). Si la cámara está denegada
  o falla, el partido sigue jugándose sin cámara.
- Base de datos local v2 (migración v1 → v2 sin perder los partidos de la
  Etapa 0) y almacenamiento seguro preparado para las claves de
  transmisión (Etapa 5). No hay ninguna clave guardada.

## Qué NO hace todavía

Grabación, RTMP, Facebook Live, jugadores, logos de equipos (Etapa 6,
como imágenes subidas desde el teléfono), cuentas ni pagos. El marcador
tiene un solo diseño fijo en esta etapa; las plantillas editables llegan
en la Etapa 6. Ver `docs/ARQUITECTURA.md` para saber dónde irá cada cosa.

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
