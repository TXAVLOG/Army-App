package vn.army.txa

import io.flutter.app.FlutterApplication
import android.content.Context
import android.content.Intent
import android.util.Log
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import kotlin.system.exitProcess

class MainApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        
        // Catch-All Root Global Uncaught Exception Handler for ALL Android Native Crashes
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val sw = StringWriter()
                throwable.printStackTrace(PrintWriter(sw))
                val stackTraceString = sw.toString()

                Log.e("TXANativeLogger", "🔥 NATIVE UNCAUGHT CRASH: ${throwable.message}", throwable)

                // 1. Save native crash info to SharedPreferences for Flutter TXALogger retrieval
                val prefs = getSharedPreferences("txa_native_crash_prefs", Context.MODE_PRIVATE)
                prefs.edit().apply {
                    putString("pending_native_crash_msg", throwable.message ?: "Unknown Native Exception (${throwable.javaClass.simpleName})")
                    putString("pending_native_crash_trace", stackTraceString)
                    putLong("pending_native_crash_time", System.currentTimeMillis())
                    putBoolean("has_pending_native_crash", true)
                    commit() // Use synchronous commit for immediate persistence before process termination
                }

                // 2. Backup write to native_crash.log file in cache directory
                val logFile = File(cacheDir, "native_crash.log")
                logFile.writeText("=== NATIVE CRASH ===\nTimestamp: ${System.currentTimeMillis()}\nError: ${throwable.message}\nTrace:\n$stackTraceString")

                // 3. Immediately Relaunch MainActivity to show TXACrashScreen instead of returning to Home launcher
                val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    putExtra("is_native_crash_relaunch", true)
                }
                if (intent != null) {
                    startActivity(intent)
                    // Terminate current crashed process cleanly
                    android.os.Process.killProcess(android.os.Process.myPid())
                    exitProcess(10)
                    return@setDefaultUncaughtExceptionHandler
                }
            } catch (e: Exception) {
                Log.e("TXANativeLogger", "Failed to process native crash", e)
            }

            defaultHandler?.uncaughtException(thread, throwable)
        }
    }
}
