package com.kayto.kayto.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.kayto.kayto.service.KaytoVpnService
import com.kayto.kayto.storage.KaytoStorage

class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (Intent.ACTION_BOOT_COMPLETED == action ||
            "android.intent.action.QUICKBOOT_POWERON" == action ||
            "com.htc.intent.action.QUICKBOOT_POWERON" == action
        ) {
            val storage = KaytoStorage(context)
            if (storage.isVpnEnabled()) {
                Log.i("BootReceiver", "Boot completed; reviving Kayto VPN Service")
                val vpnIntent = Intent(context, KaytoVpnService::class.java).apply {
                    this.action = KaytoVpnService.ACTION_START
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(vpnIntent)
                } else {
                    context.startService(vpnIntent)
                }
            }
        }
    }
}
