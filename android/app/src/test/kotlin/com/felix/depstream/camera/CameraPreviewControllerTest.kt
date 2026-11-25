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

    // Selección de tamaño con sensor de lado (lista en orientación
    // del sensor, como la da el S24 Ultra: 1280x720 aparece 720x1280).
    // Sin trasponer, la selección directa no encontraba ningún 16:9 y
    // caía al 4:3 más grande, que el visor 16:9 estiraba.

    @Test
    fun `con sensor a 90 la lista del S24 Ultra elige 1280x720 de pantalla y bufer 720x1280`() {
        val sensorSizes = listOf(
            PreviewSize(720, 1280),
            PreviewSize(1080, 1920),
            PreviewSize(3024, 4032),
        )
        val displaySize = CameraPreviewMath.selectPreviewSize(
            CameraPreviewMath.toDisplayOrientation(sensorSizes, 90),
        )
        assertEquals(PreviewSize(1280, 720), displaySize)
        assertEquals(
            PreviewSize(720, 1280),
            CameraPreviewMath.toSensorOrientation(displaySize!!, 90),
        )
    }

    @Test
    fun `con sensor a 90 sin 720p elige el 16-9 mas grande por debajo y su bufer traspuesto`() {
        val sensorSizes = listOf(
            PreviewSize(480, 640),
            PreviewSize(540, 960),
            PreviewSize(1080, 1920),
        )
        val displaySize = CameraPreviewMath.selectPreviewSize(
            CameraPreviewMath.toDisplayOrientation(sensorSizes, 90),
        )
        assertEquals(PreviewSize(960, 540), displaySize)
        assertEquals(
            PreviewSize(540, 960),
            CameraPreviewMath.toSensorOrientation(displaySize!!, 90),
        )
    }

    @Test
    fun `con sensor a 90 sin ningun 16-9 cae al mas grande por area traspuesto`() {
        val sensorSizes = listOf(PreviewSize(480, 640), PreviewSize(240, 320))
        val displaySize = CameraPreviewMath.selectPreviewSize(
            CameraPreviewMath.toDisplayOrientation(sensorSizes, 90),
        )
        assertEquals(PreviewSize(640, 480), displaySize)
        assertEquals(
            PreviewSize(480, 640),
            CameraPreviewMath.toSensorOrientation(displaySize!!, 90),
        )
    }

    @Test
    fun `con sensor a 0 la lista ya esta en orientacion de pantalla y no se traspone`() {
        val sizes = listOf(PreviewSize(1280, 720), PreviewSize(1920, 1080))
        val displaySize = CameraPreviewMath.selectPreviewSize(
            CameraPreviewMath.toDisplayOrientation(sizes, 0),
        )
        assertEquals(PreviewSize(1280, 720), displaySize)
        assertEquals(
            PreviewSize(1280, 720),
            CameraPreviewMath.toSensorOrientation(displaySize!!, 0),
        )
    }

    @Test
    fun `trasponer dos veces devuelve el tamano original`() {
        val size = PreviewSize(720, 1280)
        assertEquals(
            size,
            CameraPreviewMath.toSensorOrientation(
                CameraPreviewMath.toDisplayOrientation(listOf(size), 90).first(),
                90,
            ),
        )
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
