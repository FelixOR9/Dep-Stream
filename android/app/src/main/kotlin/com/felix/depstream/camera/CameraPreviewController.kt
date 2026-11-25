package com.felix.depstream.camera

import android.annotation.SuppressLint
import android.graphics.SurfaceTexture
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.hardware.display.DisplayManager
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.view.Display
import android.view.Surface
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Sesión de vista previa Camera2 (Etapa 2).
 *
 * Dueño de la cámara trasera mientras la pantalla de cámara está
 * abierta. La vista previa llega a Flutter por `TextureRegistry`:
 * Dart pide una textura y aquí se crea el `SurfaceTexture` que se
 * pasa como superficie de la sesión; el widget de Flutter es un
 * `Texture(textureId)`, no se dibuja ningún píxel en Dart.
 *
 * La rotación del preview NO se aplica aquí: `SurfaceTexture` no
 * tiene `setTransform` (ese método es de `TextureView`, que no se
 * usa: la textura la dibuja el widget `Texture` de Flutter). La
 * rotación calculada se devuelve a Dart junto con el id de la
 * textura y es el widget quien gira la imagen con `RotatedBox`.
 *
 * La rotación es EN VIVO, no de una sola vez al abrir: al entrar a
 * la pantalla el teléfono todavía está en vertical y el bloqueo a
 * horizontal ocurre justo después, así que leer la rotación solo al
 * abrir dejaba la textura girada 90° toda la sesión (y girar 180°
 * con la cámara abierta tampoco actualizaba nada). Un
 * `DisplayManager.DisplayListener` activo solo mientras la sesión
 * está abierta recalcula el giro a cada cambio de pantalla y lo
 * empuja a Dart por el `EventChannel` de rotación; además la
 * respuesta de apertura lleva el giro recalculado en ese momento,
 * no el de la llamada inicial.
 *
 * Los tamaños de `getOutputSizes` vienen en orientación del sensor:
 * se elige el tamaño en orientación de pantalla (1280x720) y el
 * búfer se pide en orientación del sensor (720x1280 con sensor a
 * 90°); sin esa trasposición la selección caía a un 4:3 que el visor
 * 16:9 estiraba (imagen distorsionada, fix Etapa 2).
 *
 * - Sin audio: solo vídeo. El micrófono no se abre en esta etapa.
 * - Sin grabación: la Etapa 3 añadirá una superficie de `MediaCodec`
 *   a esta misma sesión; aquí solo hay vista previa.
 * - Cierre ordenado siempre (sesión → dispositivo → hilo), también
 *   si `open()` falló a medias: una cámara sin cerrar queda bloqueada
 *   para la siguiente apertura y para otras apps.
 * - Los errores llevan código propio y la etapa en la que ocurrieron,
 *   nunca un mensaje genérico: `camera_unavailable`, `camera_in_use`,
 *   `permission_denied`, `session_failed`.
 */
class CameraPreviewController(
    private val cameraManager: CameraManager,
    private val textureRegistry: TextureRegistry,
    /** Rotación de la pantalla en grados (0/90/180/270), para el giro de la textura. */
    private val displayRotationDegrees: () -> Int = { 0 },
    /** Para vigilar los cambios de rotación de pantalla en vivo. Sin él no hay avisos. */
    private val displayManager: DisplayManager? = null,
) {

    private val lifecycle = CameraSessionLifecycle()
    private var backgroundThread: HandlerThread? = null
    private var backgroundHandler: Handler? = null
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var pendingResult: MethodChannel.Result? = null
    private var lastErrorCode: String? = null

    /** Giro del preview en vivo de la sesión abierta (null sin sesión). */
    private var rotationTracker: PreviewRotationTracker? = null

    /** Rotación del preview en grados (0/90/180/270), la actual, no la de la apertura. */
    private val lastRotationDegrees: Int get() = rotationTracker?.currentDegrees ?: 0

    /** Destino de los avisos de giro en vivo (el `EventChannel` de rotación). */
    private var rotationSink: EventChannel.EventSink? = null

    /** Vigilante de cambios de pantalla, activo solo con la sesión abierta. */
    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) {}
        override fun onDisplayRemoved(displayId: Int) {}
        override fun onDisplayChanged(displayId: Int) {
            if (displayId != Display.DEFAULT_DISPLAY) return
            notifyRotationIfChanged()
        }
    }
    private var rotationListenerRegistered = false

    /** Estado actual, para `getCameraState` y para diagnóstico. */
    val state: CameraLifecycleState get() = lifecycle.state

    /** Id de la textura abierta, o -1 si no hay sesión. */
    var textureId: Long = -1L
        private set

    /** Mapa de estado para Dart: `state` y `errorCode` (o null). */
    fun stateMap(): Map<String, Any?> = mapOf(
        "state" to lifecycle.state.name,
        "errorCode" to lastErrorCode,
    )

    /**
     * Abre la cámara trasera y responde con el id de la textura.
     * La respuesta es asíncrona (abrir el dispositivo y crear la
     * sesión llevan callbacks): el `Result` se guarda y se responde
     * exactamente una vez.
     */
    @SuppressLint("MissingPermission")
    fun openCamera(result: MethodChannel.Result) {
        synchronized(this) {
            if (lifecycle.state == CameraLifecycleState.open) {
                // Ya hay sesión: no-op, se devuelve la textura que ya
                // existe con su rotación (la misma de la apertura).
                result.success(openResultMap())
                return
            }
            if (!lifecycle.requestOpen()) {
                result.error(
                    "already_open",
                    "La cámara ya se está abriendo.",
                    null,
                )
                return
            }
            pendingResult = result
            lastErrorCode = null
        }
        try {
            startBackgroundThread()
            val cameraId = chooseBackCameraId()
            if (cameraId == null) {
                fail("camera_unavailable", "No hay cámara trasera.")
                return
            }
            val characteristics = cameraManager.getCameraCharacteristics(cameraId)
            val sensorOrientation = characteristics.get(
                CameraCharacteristics.SENSOR_ORIENTATION,
            ) ?: 0
            val sensorSizes = characteristics
                .get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                ?.getOutputSizes(SurfaceTexture::class.java)
                ?.map { PreviewSize(it.width, it.height) }
                ?: emptyList()
            // `getOutputSizes` devuelve los tamaños en orientación del
            // sensor: con el sensor del S24 Ultra a 90°, el 1280x720
            // aparece como 720x1280 y la selección directa no lo
            // encontraba (caía al 4:3 más grande, que el visor 16:9
            // estiraba y se veía distorsionado). Se elige en
            // orientación de pantalla y el búfer vuelve a orientación
            // del sensor, que es lo que espera `setDefaultBufferSize`.
            val displaySize = CameraPreviewMath.selectPreviewSize(
                CameraPreviewMath.toDisplayOrientation(
                    sensorSizes,
                    sensorOrientation,
                ),
            )
            if (displaySize == null) {
                fail("camera_unavailable", "La cámara no ofrece tamaños de vista previa.")
                return
            }
            val previewSize = CameraPreviewMath.toSensorOrientation(
                displaySize,
                sensorOrientation,
            )
            val entry = textureRegistry.createSurfaceTexture()
            val surfaceTexture = entry.surfaceTexture()
            surfaceTexture.setDefaultBufferSize(previewSize.width, previewSize.height)
            // La rotación se calcula aquí pero NO se aplica al
            // SurfaceTexture (no tiene setTransform): se guarda y se
            // devuelve a Dart, que gira el widget Texture.
            // Es solo el valor inicial: el vigilante de pantalla lo
            // mantiene al día en vivo (ver `notifyRotationIfChanged`) y
            // la respuesta de apertura lo recalcula antes de responder,
            // porque al abrir el teléfono aún está en vertical y el
            // bloqueo a horizontal ocurre justo después.
            rotationTracker = PreviewRotationTracker(
                sensorOrientation = sensorOrientation,
                displayRotationDegrees = displayRotationDegrees(),
                frontCamera = false,
            )
            registerRotationListener()
            textureEntry = entry
            textureId = entry.id()
            cameraManager.openCamera(
                cameraId,
                object : CameraDevice.StateCallback() {
                    override fun onOpened(device: CameraDevice) {
                        cameraDevice = device
                        createSession(device, surfaceTexture)
                    }

                    override fun onDisconnected(device: CameraDevice) {
                        fail("camera_in_use", "La cámara se desconectó.")
                    }

                    override fun onError(device: CameraDevice, error: Int) {
                        fail("camera_in_use", "La cámara falló al abrir (código $error).")
                    }
                },
                backgroundHandler,
            )
        } catch (e: CameraAccessException) {
            fail("camera_unavailable", "No se pudo acceder a la cámara: ${e.message}")
        } catch (e: SecurityException) {
            fail("permission_denied", "Sin permiso de cámara.")
        }
    }

    /** Cierra la sesión. Idempotente: cerrar sin abrir no falla. */
    fun closeCamera() {
        synchronized(this) {
            if (!lifecycle.close()) return
            closeSessionLocked()
            textureId = -1L
            lastErrorCode = null
        }
    }

    private fun createSession(device: CameraDevice, surfaceTexture: SurfaceTexture) {
        try {
            val surface = Surface(surfaceTexture)
            device.createCaptureSession(
                listOf(surface),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        captureSession = session
                        try {
                            val request = device.createCaptureRequest(
                                CameraDevice.TEMPLATE_PREVIEW,
                            ).apply {
                                addTarget(surface)
                                set(
                                    CaptureRequest.CONTROL_AF_MODE,
                                    CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO,
                                )
                            }.build()
                            session.setRepeatingRequest(
                                request,
                                null,
                                backgroundHandler,
                            )
                            synchronized(this@CameraPreviewController) {
                                lifecycle.markOpened()
                                // La pantalla ya giró a horizontal
                                // mientras se abría la cámara: el giro
                                // de la respuesta es el de ahora, no
                                // el de la llamada a `openCamera`.
                                rotationTracker?.refresh(
                                    displayRotationDegrees(),
                                )
                                pendingResult?.success(openResultMap())
                                pendingResult = null
                            }
                        } catch (e: CameraAccessException) {
                            fail(
                                "session_failed",
                                "No se pudo iniciar la vista previa: ${e.message}",
                            )
                        }
                    }

                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        fail("session_failed", "No se pudo configurar la sesión de cámara.")
                    }
                },
                backgroundHandler,
            )
        } catch (e: CameraAccessException) {
            fail("session_failed", "No se pudo crear la sesión: ${e.message}")
        }
    }

    private fun chooseBackCameraId(): String? {
        return try {
            cameraManager.cameraIdList.firstOrNull { id ->
                cameraManager.getCameraCharacteristics(id).get(
                    CameraCharacteristics.LENS_FACING,
                ) == CameraCharacteristics.LENS_FACING_BACK
            }
        } catch (e: CameraAccessException) {
            null
        }
    }

    /** Respuesta de `openCamera`: id de textura + rotación del preview.
     *
     * Dart gira el widget `Texture` con estos grados (múltiplo de 90):
     * la rotación no se puede aplicar en Kotlin porque `SurfaceTexture`
     * no tiene `setTransform`.
     */
    private fun openResultMap(): Map<String, Any> = mapOf(
        "textureId" to textureId,
        "rotationDegrees" to lastRotationDegrees,
    )

    /** Destino de los avisos de giro en vivo (lo pone `MainActivity`). */
    fun setRotationSink(sink: EventChannel.EventSink?) {
        rotationSink = sink
    }

    /**
     * Empieza a vigilar la rotación de pantalla, solo con la sesión
     * abierta (o abriéndose). Sin `DisplayManager` no hay avisos en
     * vivo: el giro queda en el de la apertura.
     */
    private fun registerRotationListener() {
        val manager = displayManager ?: return
        if (rotationListenerRegistered) return
        manager.registerDisplayListener(
            displayListener,
            Handler(Looper.getMainLooper()),
        )
        rotationListenerRegistered = true
    }

    /** Deja de vigilar la rotación de pantalla. Idempotente. */
    private fun unregisterRotationListener() {
        if (!rotationListenerRegistered) return
        rotationListenerRegistered = false
        try {
            displayManager?.unregisterDisplayListener(displayListener)
        } catch (_: Exception) {
            // Cerrar nunca debe lanzar: lo peor ya pasó.
        }
    }

    /**
     * La pantalla cambió: recalcula el giro y, solo si cambió de
     * verdad y la sesión sigue abierta, lo empuja a Dart por el
     * `EventChannel` de rotación. Sin sesión o sin suscriptor no se
     * emite nada. Corre en el hilo principal (el listener usa el
     * handler principal), así que `success` es seguro aquí.
     */
    private fun notifyRotationIfChanged() {
        val tracker = rotationTracker ?: return
        if (lifecycle.state != CameraLifecycleState.open &&
            lifecycle.state != CameraLifecycleState.opening
        ) {
            return
        }
        if (!tracker.refresh(displayRotationDegrees())) return
        try {
            rotationSink?.success(
                mapOf("rotationDegrees" to tracker.currentDegrees),
            )
        } catch (_: Exception) {
            // Si Dart ya no escucha, el giro queda guardado y la
            // próxima apertura lo leerá de la respuesta.
        }
    }

    private fun startBackgroundThread() {
        val thread = HandlerThread("DepStreamCamera")
        thread.start()
        backgroundThread = thread
        backgroundHandler = Handler(thread.looper)
    }

    /** Falla la apertura en curso: cierra lo parcial y responde el error. */
    private fun fail(code: String, message: String) {
        synchronized(this) {
            lifecycle.markFailed()
            lastErrorCode = code
            closeSessionLocked()
            textureId = -1L
            pendingResult?.error(code, message, null)
            pendingResult = null
        }
    }

    /** Cierra sesión, dispositivo, hilo y textura. Llamar con el bloqueo tomado. */
    private fun closeSessionLocked() {
        unregisterRotationListener()
        rotationTracker = null
        try {
            captureSession?.close()
        } catch (_: Exception) {
            // Cerrar nunca debe lanzar: lo peor ya pasó.
        }
        captureSession = null
        try {
            cameraDevice?.close()
        } catch (_: Exception) {
        }
        cameraDevice = null
        try {
            textureEntry?.release()
        } catch (_: Exception) {
        }
        textureEntry = null
        backgroundThread?.quitSafely()
        backgroundThread = null
        backgroundHandler = null
    }
}
