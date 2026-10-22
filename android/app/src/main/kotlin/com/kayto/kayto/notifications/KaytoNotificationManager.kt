package com.kayto.kayto.notifications

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.kayto.kayto.MainActivity
import com.kayto.kayto.model.NetworkSource

class KaytoNotificationManager(private val context: Context) {

    private val notificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    companion object {
        const val CHANNEL_VPN = "kayto_vpn_channel"
        const val CHANNEL_ALERTS = "kayto_alerts_channel"
        const val CHANNEL_ENFORCEMENT = "kayto_enforcement_channel"

        const val NOTIFICATION_ID_VPN = 1001
        private var alertNotificationId = 2000
    }

    init {
        createChannels()
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // VPN Foreground channel
            val vpnChannel = NotificationChannel(
                CHANNEL_VPN,
                "Kayto Enforcement Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows live status of active data limit enforcement"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(vpnChannel)

            // Limit warning alerts channel
            val alertsChannel = NotificationChannel(
                CHANNEL_ALERTS,
                "Kayto Usage Warnings",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifies when apps reach 50%, 70%, or 90% of daily data quota"
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(alertsChannel)

            // Enforcement / Blocked alerts channel
            val enforcementChannel = NotificationChannel(
                CHANNEL_ENFORCEMENT,
                "Kayto Enforcement Actions",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifies when an app exceeds 100% of its quota and is blocked"
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(enforcementChannel)
        }
    }

    fun buildVpnNotification(
        monitoredCount: Int,
        blockedSourcesCount: Int,
        blockedPackets: Long
    ): Notification {
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val title = "Kayto Protection Active"
        val contentText = if (blockedSourcesCount > 0) {
            "$monitoredCount apps monitored · $blockedSourcesCount limit(s) reached · $blockedPackets blocked"
        } else {
            "$monitoredCount apps monitored · All networks within limits"
        }

        return NotificationCompat.Builder(context, CHANNEL_VPN)
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentTitle(title)
            .setContentText(contentText)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    fun showThresholdNotification(
        appLabel: String,
        source: NetworkSource,
        threshold: Int
    ) {
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            alertNotificationId,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val sourceName = when (source) {
            NetworkSource.WIFI -> "Wi-Fi"
            NetworkSource.SIM_1 -> "SIM 1"
            NetworkSource.SIM_2 -> "SIM 2"
        }

        val (title, body, channelId) = when (threshold) {
            100 -> Triple(
                "$appLabel blocked on $sourceName",
                "$appLabel's $sourceName daily allowance is exhausted. $sourceName access has been revoked.",
                CHANNEL_ENFORCEMENT
            )
            90 -> Triple(
                "Critical limit warning: $appLabel",
                "$appLabel is close to its $sourceName limit (90% reached).",
                CHANNEL_ALERTS
            )
            70 -> Triple(
                "Quota notice: $appLabel",
                "$appLabel has used 70% of its $sourceName allowance today.",
                CHANNEL_ALERTS
            )
            else -> Triple(
                "Usage notice: $appLabel",
                "$appLabel has used 50% of its $sourceName allowance today.",
                CHANNEL_ALERTS
            )
        }

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        notificationManager.notify(alertNotificationId++, notification)
    }
}
