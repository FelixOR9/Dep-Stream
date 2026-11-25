package com.felix.depstream.camera

/**
 * Lógica pura de la vista previa de cámara, sin Android.
 *
 * Se separa del `CameraPreviewController` a propósito: `android.util.Size`
 * y las clases del framework no se pueden usar en tests unitarios
 * (el android.jar de los tests son stubs), así que la selección de
 * tamaño y la rotación se deciden aquí con enteros y se prueban con
 * JUnit en CI.
 */

/** Tamaño de vista previa, en píxeles. */
data class PreviewSize(val width: Int, val height: Int) {
    val area: Int get() = width * height
    val is16by9: Boolean get() = width * 9 == height * 16
}

object CameraPreviewMath {

    /** Tamaño objetivo de la vista previa (lienzo del overlay). */
    val TARGET = PreviewSize(1280, 720)

    /**
     * Elige el tamaño de vista previa entre los que ofrece el dispositivo.
     *
     * Reglas (plan §3.2), en orden:
     * 1. 1280x720 exacto, si está.
     * 2. Si no, el 16:9 más grande con altura <= 720.
     * 3. Si no hay ningún 16:9, el más grande por área.
     * 4. Lista vacía: `null` (nunca se inventa un tamaño).
     */
    fun selectPreviewSize(sizes: List<PreviewSize>): PreviewSize? {
        if (sizes.isEmpty()) return null
        val exact = sizes.firstOrNull { it == TARGET }
        if (exact != null) return exact
        val below720 = sizes
            .filter { it.is16by9 && it.height <= TARGET.height }
            .maxByOrNull { it.height }
        if (below720 != null) return below720
        return sizes.maxByOrNull { it.area }
    }

    /**
     * Grados que hay que girar la textura para que la imagen se vea
     * derecha en la pantalla.
     *
     * Fórmula estándar de Camera2: para la cámara trasera, la rotación
     * es (orientación del sensor − rotación de la pantalla); para la
     * delantera se suma. Con el sensor del S24 Ultra a 90°:
     * en vertical (rotación 0) hacen falta 90°; en horizontal a la
     * izquierda (rotación 90) hacen falta 0°; en horizontal a la derecha
     * (rotación 270) hacen falta 180°.
     */
    fun previewRotationDegrees(
        sensorOrientation: Int,
        displayRotationDegrees: Int,
        frontCamera: Boolean,
    ): Int {
        return if (frontCamera) {
            (sensorOrientation + displayRotationDegrees) % 360
        } else {
            (sensorOrientation - displayRotationDegrees + 360) % 360
        }
    }
}

/** Estados del ciclo de vida de una sesión de cámara. */
enum class CameraLifecycleState { closed, opening, open, error }

/**
 * Máquina de estados de la sesión, pura y probada con JUnit.
 *
 * Reglas: abrir solo desde `closed` o `error`; abrir dos veces sin
 * cerrar es no-op (la segunda devuelve `false`, nunca dos sesiones);
 * cerrar es idempotente (cerrar sin abrir devuelve `false` y no falla);
 * un fallo a medias deja el estado en `error`, desde donde se puede
 * volver a abrir o cerrar limpio.
 */
class CameraSessionLifecycle {

    var state: CameraLifecycleState = CameraLifecycleState.closed
        private set

    /** Pide abrir: `true` si se pasa a `opening`, `false` si ya hay sesión. */
    fun requestOpen(): Boolean {
        if (state != CameraLifecycleState.closed &&
            state != CameraLifecycleState.error
        ) {
            return false
        }
        state = CameraLifecycleState.opening
        return true
    }

    /** La sesión quedó abierta (solo desde `opening`). */
    fun markOpened() {
        if (state == CameraLifecycleState.opening) {
            state = CameraLifecycleState.open
        }
    }

    /** La sesión falló (desde `opening` o desde `open`, p. ej. desconexión). */
    fun markFailed() {
        if (state == CameraLifecycleState.opening ||
            state == CameraLifecycleState.open
        ) {
            state = CameraLifecycleState.error
        }
    }

    /** Cierra: `true` si había algo que cerrar, `false` si ya estaba cerrada. */
    fun close(): Boolean {
        if (state == CameraLifecycleState.closed) return false
        state = CameraLifecycleState.closed
        return true
    }
}
