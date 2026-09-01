package vn.army.txa

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "vn.army.txa/battery_optimization"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Create custom notification channel that bypasses Do Not Disturb (DND)
        createNotificationChannel()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vn.army.txa/security").setMethodCallHandler { call, result ->
            when (call.method) {
                "setScreenSecurity" -> {
                    val enable = call.argument<Boolean>("enable") ?: true
                    if (enable) {
                        window?.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window?.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(true)
                }
                "isDndAccessGranted" -> {
                    result.success(isDndAccessGranted())
                }
                "requestDndAccess" -> {
                    requestDndAccess()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vn.army.txa/app_icon").setMethodCallHandler { call, result ->
            when (call.method) {
                "changeAppIcon" -> {
                    val iconName = call.argument<String>("iconName") ?: "default_gold"
                    val aliasMap = mapOf(
                        "national_day_29" to "vn.army.txa.MainActivityNationalDay",
                        "default_gold" to "vn.army.txa.MainActivityDefault",
                        "midnight_dark" to "vn.army.txa.MainActivityMidnight",
                        "cyberpunk_neon" to "vn.army.txa.MainActivityCyberpunk",
                        "sakura_pink" to "vn.army.txa.MainActivitySakura",
                        "ocean_breeze" to "vn.army.txa.MainActivityOcean",
                        "sunset_glow" to "vn.army.txa.MainActivitySunset",
                        "matrix_matrix" to "vn.army.txa.MainActivityMatrix",
                        "fire_dragon" to "vn.army.txa.MainActivityFire",
                        "galaxy_cosmic" to "vn.army.txa.MainActivityGalaxy",
                        "frost_ice" to "vn.army.txa.MainActivityFrost",
                        "emerald_gem" to "vn.army.txa.MainActivityEmerald",
                        "ruby_luxury" to "vn.army.txa.MainActivityRuby",
                        "amethyst_purple" to "vn.army.txa.MainActivityAmethyst",
                        "retro_synthwave" to "vn.army.txa.MainActivitySynthwave",
                        "matcha_zen" to "vn.army.txa.MainActivityMatcha",
                        "phantom_ghost" to "vn.army.txa.MainActivityPhantom",
                        "golden_king" to "vn.army.txa.MainActivityGoldenKing",
                        "diamond_ultra" to "vn.army.txa.MainActivityDiamond",
                        "blood_moon" to "vn.army.txa.MainActivityBloodMoon",
                        "aurora_lights" to "vn.army.txa.MainActivityAurora",
                        "space_blackhole" to "vn.army.txa.MainActivityBlackHole",
                        "coffee_caramel" to "vn.army.txa.MainActivityCoffee",
                        "neon_toxic" to "vn.army.txa.MainActivityToxic",
                        "quantum_portal" to "vn.army.txa.MainActivityQuantum",
                        "infinity_titan" to "vn.army.txa.MainActivityTitan"
                    )
                    val targetAlias = aliasMap[iconName] ?: "vn.army.txa.MainActivityDefault"
                    try {
                        val pm = packageManager
                        android.util.Log.d("TXAAppIcon", "Đang chuyển đổi launcher alias sang: $targetAlias (Yêu cầu icon: $iconName)")
                        
                        // 1. Kích hoạt target alias trước để tránh trạng thái không có icon nào hiển thị
                        val targetComp = android.content.ComponentName(packageName, targetAlias)
                        pm.setComponentEnabledSetting(
                            targetComp,
                            android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                            android.content.pm.PackageManager.DONT_KILL_APP
                        )

                        // 2. Vô hiệu hóa các alias còn lại
                        for ((_, aliasComponent) in aliasMap) {
                            if (aliasComponent != targetAlias) {
                                val comp = android.content.ComponentName(packageName, aliasComponent)
                                pm.setComponentEnabledSetting(
                                    comp,
                                    android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                    android.content.pm.PackageManager.DONT_KILL_APP
                                )
                            }
                        }
                        android.util.Log.d("TXAAppIcon", "Đã kích hoạt alias $targetAlias thành công!")
                        result.success(mapOf(
                            "success" to true,
                            "appliedAlias" to targetAlias,
                            "iconName" to iconName
                        ))
                    } catch (e: Exception) {
                        android.util.Log.e("TXAAppIcon", "Lỗi chuyển đổi launcher alias: ${e.message}", e)
                        result.error("ICON_ERROR", "Failed to change launcher icon: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "army_channel"
            val channelName = "Army Notifications"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = "Default channel for Army app notifications"
                setBypassDnd(true)
                enableLights(true)
                enableVibration(true)
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            return pm.isIgnoringBatteryOptimizations(packageName)
        }
        return true
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!isIgnoringBatteryOptimizations()) {
                val intent = Intent().apply {
                    action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                    data = Uri.parse("package:$packageName")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
            }
        }
    }

    private fun isDndAccessGranted(): Boolean {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            nm.isNotificationPolicyAccessGranted
        } else {
            true
        }
    }

    private fun requestDndAccess() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!isDndAccessGranted()) {
                val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
            }
        }
    }
}
