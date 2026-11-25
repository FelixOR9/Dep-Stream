package com.felix.depstream.permissions

/**
 * Decisión pura del estado de un permiso, sin Android. Es la única lógica
 * que se prueba con JUnit sin Robolectric.
 *
 * Reglas (iguales en Dart y en Kotlin):
 * - Concedido: `granted`.
 * - No concedido y el sistema dice que se puede volver a explicar por qué
 *   se pide (`shouldShowRequestPermissionRationale`): `denied`.
 * - No concedido, sin rationale y ya se pidió antes: `permanentlyDenied`
 *   (el usuario marcó "no volver a preguntar" o lo negó desde ajustes).
 * - No concedido, sin rationale y nunca se pidió: `notRequested`.
 *
 * Un estado desconocido nunca se presenta como concedido.
 */
object PermissionStateResolver {

    fun resolve(
        granted: Boolean,
        shouldShowRationale: Boolean,
        requestedBefore: Boolean,
    ): String {
        if (granted) return "granted"
        if (shouldShowRationale) return "denied"
        if (requestedBefore) return "permanentlyDenied"
        return "notRequested"
    }
}
