package com.felix.depstream.permissions

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel

/**
 * Permisos reales de Dep-Stream (Etapa 0).
 *
 * - Los estados se comprueban en cada llamada; nada se cachea.
 * - El historial de "ya se pidió antes" vive en SharedPreferences con la
 *   clave `depstream_permission_history`, nunca en SQLite. Es lo que permite
 *   distinguir la primera petición de la negación permanente.
 * - Si un permiso está negado para siempre, no se vuelve a pedir en bucle:
 *   la UI ofrece "Abrir ajustes".
 */
class PermissionManager(private val activity: Activity) {

    companion object {
        const val REQUEST_CODE = 9001
        private const val PREFS_NAME = "depstream_permission_history"
        private const val KEY_REQUESTED = "requested_permissions"

        /** Permisos con su nombre de canal. POST_NOTIFICATIONS solo existe desde API 33. */
        val PERMISSIONS: List<Pair<String, String>> =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                listOf(
                    "camera" to Manifest.permission.CAMERA,
                    "microphone" to Manifest.permission.RECORD_AUDIO,
                    "notifications" to Manifest.permission.POST_NOTIFICATIONS,
                )
            } else {
                listOf(
                    "camera" to Manifest.permission.CAMERA,
                    "microphone" to Manifest.permission.RECORD_AUDIO,
                )
            }
    }

    private var pendingResult: MethodChannel.Result? = null

    /** Estado actual de cada permiso, como mapa nombre -> estado. */
    fun checkPermissions(): Map<String, String> {
        val requestedBefore = requestedBefore()
        return PERMISSIONS.associate { (name, androidPermission) ->
            name to stateOf(androidPermission, requestedBefore)
        }
    }

    /** Pide los permisos que faltan. Responde cuando el usuario contesta. */
    fun requestPermissions(result: MethodChannel.Result) {
        val missing = PERMISSIONS.filter { (_, androidPermission) ->
            ContextCompat.checkSelfPermission(activity, androidPermission) !=
                PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            result.success(checkPermissions())
            return
        }
        // Se registra que se pidió ANTES de pedirlo: si el usuario lo niega
        // y el sistema ya no muestra rationale, la próxima comprobación lo
        // verá como negado para siempre.
        markRequested(missing.map { it.second })
        pendingResult = result
        ActivityCompat.requestPermissions(
            activity,
            missing.map { it.second }.toTypedArray(),
            REQUEST_CODE,
        )
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        @Suppress("UNUSED_PARAMETER") grantResults: IntArray,
    ) {
        if (requestCode != REQUEST_CODE) return
        pendingResult?.success(checkPermissions())
        pendingResult = null
    }

    /** Abre la pantalla de ajustes de la app en el sistema. */
    fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", activity.packageName, null)
        }
        activity.startActivity(intent)
    }

    private fun stateOf(androidPermission: String, requestedBefore: Set<String>): String {
        val granted = ContextCompat.checkSelfPermission(activity, androidPermission) ==
            PackageManager.PERMISSION_GRANTED
        val rationale = ActivityCompat.shouldShowRequestPermissionRationale(
            activity,
            androidPermission,
        )
        return PermissionStateResolver.resolve(
            granted = granted,
            shouldShowRationale = rationale,
            requestedBefore = requestedBefore.contains(androidPermission),
        )
    }

    private fun requestedBefore(): Set<String> {
        val prefs = activity.getSharedPreferences(PREFS_NAME, Activity.MODE_PRIVATE)
        return prefs.getStringSet(KEY_REQUESTED, emptySet()) ?: emptySet()
    }

    private fun markRequested(permissions: List<String>) {
        val prefs = activity.getSharedPreferences(PREFS_NAME, Activity.MODE_PRIVATE)
        val updated = (requestedBefore() + permissions).toSet()
        prefs.edit().putStringSet(KEY_REQUESTED, updated).apply()
    }
}
