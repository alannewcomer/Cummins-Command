package com.cumminscommand.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createServiceNotificationChannel()
    }

    /**
     * Pre-create the notification channel used by flutter_background_service.
     *
     * The plugin creates its own channel with IMPORTANCE_LOW in BackgroundService.onCreate(),
     * but on Android 14 that can cause "Bad notification for startForeground" because the
     * channel may not exist yet or the importance is too low. Creating it here with
     * IMPORTANCE_DEFAULT ensures it exists before the service ever starts.
     *
     * If the channel already exists, this is a no-op (Android ignores duplicate creates).
     */
    private fun createServiceNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "cummins_command_obd",
                "OBD Monitoring",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Keeps Bluetooth connection alive for OBD monitoring"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
