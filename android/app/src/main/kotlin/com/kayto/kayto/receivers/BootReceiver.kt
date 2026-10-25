package com.kayto.kayto.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat
import com.kayto.kayto.service.KaytoVpnService
import com.kayto.kayto.storage.KaytoStorage

class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (Intent.ACTION_BOOT_COMPLETED == action ||
            "android.intent.action.QUICKBOOT_POWERON" == action ||
            "com.htc.intent.action.QUICKBOOT_POWERON" == action
        ) {
            Log.i("Kayto", "Kayto boot received")

            val storage = KaytoStorage(context)
            // If the user had Kayto active when the device shut down and pin service is enabled
            if (storage.isVpnEnabled() && storage.isPinServiceEnabled()) {
                Log.i("Kayto", "Restarting KaytoVpnService after boot")
                val vpnIntent = Intent(context, KaytoVpnService::class.java).apply {
                    this.action = KaytoVpnService.ACTION_START
                }
                ContextCompat.startForegroundService(context, vpnIntent)
            }
        }
    }
}
