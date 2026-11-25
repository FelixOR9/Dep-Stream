package com.felix.depstream.stream

import android.app.Service
import android.content.Intent
import android.os.IBinder

/**
 * Preparación Etapa 0: el servicio existe y está registrado en el
 * AndroidManifest con `foregroundServiceType="camera|microphone"` para que
 * las Etapas 3 (grabación) y 5 (transmisión) puedan arrancarlo.
 *
 * En la Etapa 0 no hace nada: si alguien lo arrancara, se detiene solo.
 * Nunca muestra una notificación de "Grabando" sin estar grabando.
 */
class DepStreamForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        stopSelf(startId)
        return START_NOT_STICKY
    }
}
