package com.kayto.kayto.workers

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.kayto.kayto.notifications.KaytoNotificationManager
import com.kayto.kayto.service.KaytoVpnService
import com.kayto.kayto.storage.KaytoStorage

class KaytoHeartbeatWorker(
    private val appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    override suspend fun doWork(): Result {
        val storage = KaytoStorage(appContext)

        if (!storage.isPinServiceEnabled()) {
            return Result.success()
        }

        val isRunning = KaytoVpnService.isServiceRunning()
        val shouldBeRunning = storage.isVpnEnabled()

        Log.d("Kayto", "Heartbeat check: isRunning=$isRunning, shouldBeRunning=$shouldBeRunning")

        if (shouldBeRunning && !isRunning) {
            val failCount = storage.getHeartbeatFailCount() + 1
            storage.setHeartbeatFailCount(failCount)

            Log.w("Kayto", "Kayto service expected but stopped. Attempting restart ($failCount/3)...")

            try {
                val vpnIntent = Intent(appContext, KaytoVpnService::class.java).apply {
                    action = KaytoVpnService.ACTION_START
                }
                ContextCompat.startForegroundService(appContext, vpnIntent)
            } catch (e: Exception) {
                Log.e("Kayto", "Failed to restart KaytoVpnService", e)
            }

            if (failCount >= 3) {
                val notificationManager = KaytoNotificationManager(appContext)
                notificationManager.showHeartbeatFailureNotification()
            }
        } else if (isRunning) {
            storage.resetHeartbeatFailCount()
        }

        return Result.success()
    }
}
