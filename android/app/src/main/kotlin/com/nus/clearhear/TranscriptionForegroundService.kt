package com.nus.clearhear

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class TranscriptionForegroundService : Service() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = buildNotification()
        startForeground(NOTIFICATION_ID, notification)
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = CHANNEL_DESCRIPTION
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
        builder.setContentTitle(NOTIFICATION_TITLE)
        builder.setContentText(NOTIFICATION_TEXT)
        builder.setSmallIcon(android.R.drawable.ic_dialog_info)
        builder.setOngoing(true)
        builder.setPriority(NotificationCompat.PRIORITY_LOW)
        return builder.build()
    }

    companion object {
        private const val CHANNEL_ID = "clearhear_transcription"
        private const val CHANNEL_NAME = "Transcription"
        private const val CHANNEL_DESCRIPTION = "Background transcription notification"
        private const val NOTIFICATION_TITLE = "ClearHear"
        private const val NOTIFICATION_TEXT = "Transcribing..."
        const val NOTIFICATION_ID = 1001
    }
}
