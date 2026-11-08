package com.domovoi4ik.bespredel

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.File

/**
 * VPN-сервис: создаёт TUN-интерфейс и отдаёт его в hev-socks5-tunnel,
 * который заворачивает весь трафик в локальный SOCKS5 (Xray на 127.0.0.1).
 * Само приложение исключено из VPN, чтобы ядро не зациклилось.
 */
class BespredelVpnService : VpnService() {
    private var tun: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopTunnel()
            stopSelf()
            return START_NOT_STICKY
        }
        val port = intent?.getIntExtra("socksPort", 10808) ?: 10808
        val dnsOnly = intent?.getBooleanExtra("dnsOnly", false) ?: false
        val title = intent?.getStringExtra("title") ?: "Беспредел"
        goForeground(title)
        try {
            startTunnel(port, dnsOnly)
        } catch (e: Throwable) {
            Log.e(TAG, "start failed", e)
            stopTunnel()
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun startTunnel(port: Int, dnsOnly: Boolean) {
        if (tun != null) stopTunnel()
        val b = Builder()
            .setSession("Беспредел")
            .setMtu(MTU)
            .addAddress(TUN_IP4, 32)
            .addDnsServer(FAKE_DNS)
        if (dnsOnly) {
            b.addRoute(FAKE_DNS, 32)
        } else {
            b.addRoute("0.0.0.0", 0)
            b.addAddress(TUN_IP6, 128)
            b.addRoute("::", 0)
        }
        try {
            b.addDisallowedApplication(packageName)
        } catch (_: Exception) {
        }
        if (Build.VERSION.SDK_INT >= 29) b.setMetered(false)
        val pfd = b.establish() ?: throw IllegalStateException("VPN не разрешён")
        tun = pfd

        val conf = File(filesDir, "hev.yml")
        conf.writeText(
            """
            tunnel:
              mtu: $MTU
              ipv4: $TUN_IP4
              ipv6: '$TUN_IP6'
            socks5:
              port: $port
              address: 127.0.0.1
              udp: 'udp'
            misc:
              task-stack-size: 81920
              log-level: warn
            """.trimIndent()
        )
        TProxyService.TProxyStartService(conf.absolutePath, pfd.fd)
        isRunning = true
    }

    private fun stopTunnel() {
        if (isRunning) {
            try {
                TProxyService.TProxyStopService()
            } catch (e: Throwable) {
                Log.w(TAG, "stop failed", e)
            }
        }
        try {
            tun?.close()
        } catch (_: Exception) {
        }
        tun = null
        isRunning = false
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE) else @Suppress("DEPRECATION") stopForeground(true)
    }

    private fun goForeground(title: String) {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Подключение", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
        else @Suppress("DEPRECATION") Notification.Builder(this)
        val n = builder
            .setContentTitle(title)
            .setContentText("Обход блокировок активен")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(open)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF_ID, n)
        }
    }

    override fun onRevoke() {
        stopTunnel()
        stopSelf()
    }

    override fun onDestroy() {
        stopTunnel()
        super.onDestroy()
    }

    companion object {
        const val ACTION_START = "com.domovoi4ik.bespredel.START"
        const val ACTION_STOP = "com.domovoi4ik.bespredel.STOP"
        private const val TAG = "Bespredel"
        private const val CHANNEL = "bespredel_vpn"
        private const val NOTIF_ID = 1
        private const val MTU = 8500
        private const val TUN_IP4 = "10.10.10.1"
        private const val TUN_IP6 = "fd00:bd::1"
        private const val FAKE_DNS = "10.10.10.53"

        @Volatile
        var isRunning = false
    }
}
