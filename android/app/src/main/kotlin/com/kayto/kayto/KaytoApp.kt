package com.kayto.kayto

import android.app.Application
import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.kayto.kayto.storage.KaytoStorage
import com.kayto.kayto.workers.AppListRefreshWorker
import com.kayto.kayto.workers.KaytoHeartbeatWorker
import java.util.concurrent.TimeUnit

class KaytoApp : Application() {

    companion object {
        const val WORK_HEARTBEAT = "KaytoHeartbeatWork"
        const val WORK_APP_LIST = "KaytoAppListRefreshWork"

        fun updateHeartbeatSchedule(context: Context, enabled: Boolean) {
            val workManager = WorkManager.getInstance(context)
            if (enabled) {
                val heartbeatRequest = PeriodicWorkRequestBuilder<KaytoHeartbeatWorker>(
                    15, TimeUnit.MINUTES
                ).build()
                workManager.enqueueUniquePeriodicWork(
                    WORK_HEARTBEAT,
                    ExistingPeriodicWorkPolicy.KEEP,
                    heartbeatRequest
                )
            } else {
                workManager.cancelUniqueWork(WORK_HEARTBEAT)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        scheduleAppListRefreshWorker()

        val storage = KaytoStorage(this)
        if (storage.isPinServiceEnabled()) {
            updateHeartbeatSchedule(this, true)
        }
    }

    private fun scheduleAppListRefreshWorker() {
        val refreshRequest = PeriodicWorkRequestBuilder<AppListRefreshWorker>(
            15, TimeUnit.MINUTES
        ).build()

        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            WORK_APP_LIST,
            ExistingPeriodicWorkPolicy.KEEP,
            refreshRequest
        )
    }
}
