package com.felix.depstream.camera

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pruebas unitarias Kotlin de la cámara (Etapa 2).
 *
 * Solo lógica pura, sin abrir cámara real: la selección de tamaño y
 * la rotación viven en `CameraPreviewMath` y el ciclo de vida en
 * `CameraSessionLifecycle`, a propósito, porque las clases del
 * framework de Android no se pueden usar en tests unitarios.
 */
class CameraPreviewControllerTest {

    // Selección de tamaño (plan §3.2).

    @Test
    fun `con 1280x720 disponible elige 1280x720`() {
        assertEquals(
            PreviewSize(1280, 720),
            CameraPreviewMath.selectPreviewSize(
                listOf(
                    PreviewSize(1920, 1080),
                    PreviewSize(1280, 720),
                    PreviewSize(640, 480),
                ),
            ),
        )
    }

    @Test
    fun `sin 1280x720 elige el 16-9 mas grande por debajo de 720p`() {
        assertEquals(
            PreviewSize(960, 540),
            CameraPreviewMath.selectPreviewSize(
                listOf(
                    PreviewSize(1920, 1080),
                    PreviewSize(960, 540),
                    PreviewSize(640, 360),
                ),
            ),
        )
    }

    @Test
    fun `sin ningun 16-9 elige el mas grande por area`() {
        assertEquals(
            PreviewSize(640, 480),
            CameraPreviewMath.selectPreviewSize(
                listOf(PreviewSize(640, 480), PreviewSize(320, 240)),
            ),
        )
    }

    @Test
    fun `lista vacia devuelve null, nunca un tamano inventado`() {
        assertNull(CameraPreviewMath.selectPreviewSize(emptyList()))
    }

    // Rotación de la textura (sensor a 90 grados, cámara trasera).

    @Test
    fun `sensor 90 en vertical necesita girar 90`() {
        assertEquals(
            90,
            CameraPreviewMath.previewRotationDegrees(
                sensorOrientation = 90,
                displayRotationDegrees = 0,
                frontCamera = false,
            ),
        )
    }

    @Test
    fun `sensor 90 en horizontal a la izquierda no necesita giro`() {
        assertEquals(
            0,
            CameraPreviewMath.previewRotationDegrees(
                sensorOrientation = 90,
                displayRotationDegrees = 90,
                frontCamera = false,
            ),
        )
    }

    @Test
    fun `sensor 90 en horizontal a la derecha necesita girar 180`() {
        assertEquals(
            180,
            CameraPreviewMath.previewRotationDegrees(
                sensorOrientation = 90,
                displayRotationDegrees = 270,
                frontCamera = false,
            ),
        )
    }

    // Ciclo de vida de la sesión (plan §5).

    @Test
    fun `abrir dos veces sin cerrar no abre dos sesiones`() {
        val lifecycle = CameraSessionLifecycle()
        assertTrue(lifecycle.requestOpen())
        assertFalse(lifecycle.requestOpen())
        assertEquals(CameraLifecycleState.opening, lifecycle.state)
    }

    @Test
    fun `cerrar sin abrir no falla y devuelve false`() {
        val lifecycle = CameraSessionLifecycle()
        assertFalse(lifecycle.close())
        assertEquals(CameraLifecycleState.closed, lifecycle.state)
    }

    @Test
    fun `cerrar despues de un fallo a medias deja todo cerrado`() {
        val lifecycle = CameraSessionLifecycle()
        assertTrue(lifecycle.requestOpen())
        lifecycle.markFailed()
        assertEquals(CameraLifecycleState.error, lifecycle.state)
        assertTrue(lifecycle.close())
        assertEquals(CameraLifecycleState.closed, lifecycle.state)
    }

    @Test
    fun `tras un fallo se puede volver a abrir`() {
        val lifecycle = CameraSessionLifecycle()
        assertTrue(lifecycle.requestOpen())
        lifecycle.markFailed()
        assertTrue(lifecycle.requestOpen())
        lifecycle.markOpened()
        assertEquals(CameraLifecycleState.open, lifecycle.state)
    }

    @Test
    fun `una desconexion con la sesion abierta pasa a error`() {
        val lifecycle = CameraSessionLifecycle()
        assertTrue(lifecycle.requestOpen())
        lifecycle.markOpened()
        lifecycle.markFailed()
        assertEquals(CameraLifecycleState.error, lifecycle.state)
    }
}
