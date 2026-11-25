package com.felix.depstream

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import com.felix.depstream.permissions.PermissionManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private lateinit var permissionManager: PermissionManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannel()
        permissionManager = PermissionManager(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.felix.depstream/permissions",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermissions" -> result.success(permissionManager.checkPermissions())
                "requestPermissions" -> permissionManager.requestPermissions(result)
                "openAppSettings" -> {
                    permissionManager.openAppSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (::permissionManager.isInitialized) {
            permissionManager.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    /**
     * Preparación Etapa 0: se crea el canal de notificación que usarán las
     * Etapas 3 y 5. En la Etapa 0 no se publica ninguna notificación.
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "depstream_general",
            "Dep-Stream",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Avisos mientras Dep-Stream graba o transmite"
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }
}
