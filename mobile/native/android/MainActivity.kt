package com.aiproxylauncher.ai_proxy_launcher

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.NetworkInterface

class MainActivity : FlutterActivity() {
    private val channelName = "com.aiproxylauncher/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAppDataDir" -> {
                        result.success(applicationContext.filesDir.absolutePath)
                    }
                    "getNetworkState" -> {
                        result.success(collectNetworkState())
                    }
                    "getInstalledApps" -> {
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        result.success(queryInstalledPackages(packages))
                    }
                    "launchApp" -> {
                        val pkg = call.argument<String>("packageName")
                        val url = call.argument<String>("url")
                        result.success(launchNativeAppOrUrl(pkg, url))
                    }
                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        result.success(openExternalUrl(url))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun collectNetworkState(): Map<String, Any?> {
        var vpnActive = false
        val vpnIfaces = mutableListOf<String>()
        var proxyHost: String? = null
        var proxyPort: Int? = null

        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            if (cm != null) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    val active = cm.activeNetwork
                    val caps = cm.getNetworkCapabilities(active)
                    if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                        vpnActive = true
                    }
                    @Suppress("DEPRECATION")
                    for (net in cm.allNetworks) {
                        val nc = cm.getNetworkCapabilities(net)
                        if (nc != null && nc.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                            vpnActive = true
                        }
                    }
                    val dp = cm.defaultProxy
                    if (dp != null && !dp.host.isNullOrBlank() && dp.port in 1..65535) {
                        proxyHost = dp.host
                        proxyPort = dp.port
                    }
                }
            }
        } catch (_: Exception) {
        }

        if (proxyHost.isNullOrBlank()) {
            val sysHost = System.getProperty("http.proxyHost")
            val sysPort = System.getProperty("http.proxyPort")?.toIntOrNull()
            if (!sysHost.isNullOrBlank() && sysPort != null && sysPort in 1..65535) {
                proxyHost = sysHost
                proxyPort = sysPort
            }
        }

        try {
            val ifaces = NetworkInterface.getNetworkInterfaces()
            while (ifaces != null && ifaces.hasMoreElements()) {
                val iface = ifaces.nextElement()
                if (!iface.isUp || iface.isLoopback) continue
                val name = iface.name.lowercase()
                if (name.startsWith("tun") || name.startsWith("ppp") || name.startsWith("wg") || name.startsWith("utun")) {
                    vpnActive = true
                    vpnIfaces.add(iface.name)
                }
            }
        } catch (_: Exception) {
        }

        return mapOf(
            "platform" to "android",
            "osVersion" to "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
            "vpnActive" to vpnActive,
            "vpnInterfaces" to vpnIfaces,
            "httpProxyHost" to proxyHost,
            "httpProxyPort" to proxyPort,
            "socksProxyHost" to null,
            "socksProxyPort" to null
        )
    }

    private fun queryInstalledPackages(packages: List<String>): List<String> {
        val pm = packageManager
        val installed = mutableListOf<String>()
        for (pkg in packages) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    pm.getPackageInfo(pkg, PackageManager.PackageInfoFlags.of(0))
                } else {
                    @Suppress("DEPRECATION")
                    pm.getPackageInfo(pkg, 0)
                }
                installed.add(pkg)
            } catch (_: Exception) {
            }
        }
        return installed
    }

    private fun launchNativeAppOrUrl(packageName: String?, fallbackUrl: String?): Boolean {
        if (!packageName.isNullOrBlank()) {
            try {
                val intent = packageManager.getLaunchIntentForPackage(packageName)
                if (intent != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    return true
                }
            } catch (_: Exception) {
            }
        }
        return openExternalUrl(fallbackUrl)
    }

    private fun openExternalUrl(url: String?): Boolean {
        if (url.isNullOrBlank()) return false
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}

