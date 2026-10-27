package com.example.flutter_cleaner_app

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ai_optimizer/app_cache_review")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listApps" -> {
                        try {
                            val intent = Intent(Intent.ACTION_MAIN, null).addCategory(Intent.CATEGORY_LAUNCHER)
                            val apps = packageManager.queryIntentActivities(intent, 0)
                                .mapNotNull { info ->
                                    val activity = info.activityInfo ?: return@mapNotNull null
                                    if (activity.packageName == packageName) return@mapNotNull null
                                    mapOf("packageName" to activity.packageName, "name" to info.loadLabel(packageManager).toString())
                                }
                                .distinctBy { it["packageName"] }
                                .sortedBy { (it["name"] as String).lowercase() }
                            result.success(apps)
                        } catch (e: Exception) {
                            result.error("APP_LIST_FAILED", e.message, null)
                        }
                    }
                    "openAppSettings" -> {
                        val target = call.argument<String>("packageName")
                        if (target.isNullOrBlank()) {
                            result.error("INVALID_PACKAGE", "Missing package name", null)
                        } else {
                            try {
                                startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$target")))
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("SETTINGS_FAILED", e.message, null)
                            }
                        }
                    }
                    "openStorageSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_MANAGE_ALL_APPLICATIONS_SETTINGS))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SETTINGS_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
