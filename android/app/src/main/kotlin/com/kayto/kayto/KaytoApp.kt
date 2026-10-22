package com.kayto.kayto

import android.app.Application
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.kayto.kayto.workers.AppListRefreshWorker
import java.util.concurrent.TimeUnit

class KaytoApp : Application() {

    override fun onCreate() {
        super.onCreate()
        scheduleAppListRefreshWorker()
    }

    private fun scheduleAppListRefreshWorker() {
        val refreshRequest = PeriodicWorkRequestBuilder<AppListRefreshWorker>(
            15, TimeUnit.MINUTES
        ).build()

        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "KaytoAppListRefreshWork",
            ExistingPeriodicWorkPolicy.KEEP,
            refreshRequest
        )
    }
}
