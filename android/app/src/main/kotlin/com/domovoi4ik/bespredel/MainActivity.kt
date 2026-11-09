package com.domovoi4ik.bespredel

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingPrepare: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIF)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bespredel/vpn")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "nativeDir" -> result.success(applicationInfo.nativeLibraryDir)
                    "prepare" -> {
                        val intent = VpnService.prepare(this)
                        if (intent == null) {
                            result.success(true)
                        } else {
                            pendingPrepare = result
                            startActivityForResult(intent, REQ_VPN)
                        }
                    }
                    "start" -> {
                        val i = Intent(this, BespredelVpnService::class.java).apply {
                            action = BespredelVpnService.ACTION_START
                            putExtra("socksPort", call.argument<Int>("socksPort") ?: 10808)
                            putExtra("dnsOnly", call.argument<Boolean>("dnsOnly") ?: false)
                            putExtra("title", call.argument<String>("title") ?: "Беспредел")
                        }
                        if (Build.VERSION.SDK_INT >= 26) startForegroundService(i) else startService(i)
                        result.success(true)
                    }
                    "stop" -> {
                        if (BespredelVpnService.isRunning) {
                            val i = Intent(this, BespredelVpnService::class.java).apply {
                                action = BespredelVpnService.ACTION_STOP
                            }
                            startService(i)
                        }
                        result.success(true)
                    }
                    "isRunning" -> result.success(BespredelVpnService.isRunning)
                    "openUrl" -> {
                        try {
                            startActivity(
                                Intent(Intent.ACTION_VIEW, Uri.parse(call.argument<String>("url")))
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_VPN) {
            pendingPrepare?.success(resultCode == Activity.RESULT_OK)
            pendingPrepare = null
        }
    }

    companion object {
        private const val REQ_VPN = 7001
        private const val REQ_NOTIF = 7002
    }
}
