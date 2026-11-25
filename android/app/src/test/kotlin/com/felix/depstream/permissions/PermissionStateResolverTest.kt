package com.felix.depstream.permissions

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Pruebas unitarias Kotlin de la decisión de estado de un permiso.
 * Es lógica pura, sin Android: corre con JUnit en CI.
 */
class PermissionStateResolverTest {

    @Test
    fun `concedido siempre es granted`() {
        assertEquals(
            "granted",
            PermissionStateResolver.resolve(
                granted = true,
                shouldShowRationale = false,
                requestedBefore = false,
            ),
        )
    }

    @Test
    fun `negado con rationale es denied y se puede volver a pedir`() {
        assertEquals(
            "denied",
            PermissionStateResolver.resolve(
                granted = false,
                shouldShowRationale = true,
                requestedBefore = true,
            ),
        )
    }

    @Test
    fun `negado sin rationale y pedido antes es permanentlyDenied`() {
        assertEquals(
            "permanentlyDenied",
            PermissionStateResolver.resolve(
                granted = false,
                shouldShowRationale = false,
                requestedBefore = true,
            ),
        )
    }

    @Test
    fun `nunca pedido es notRequested`() {
        assertEquals(
            "notRequested",
            PermissionStateResolver.resolve(
                granted = false,
                shouldShowRationale = false,
                requestedBefore = false,
            ),
        )
    }
}
