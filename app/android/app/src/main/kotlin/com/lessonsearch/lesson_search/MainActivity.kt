package com.lessonsearch.lesson_search

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lesson_search/notifications")
        channel?.setMethodCallHandler { call, result ->
            try {
                val notifications = SystemNotifications(this)
                when (call.method) {
                    "scheduleReminder" -> result.success(notifications.schedule(call.arguments as Map<*, *>))
                    "cancelReminder" -> {
                        notifications.cancel((call.argument<Number>("id") ?: error("Missing id")).toInt())
                        result.success(null)
                    }
                    "cancelAll" -> { notifications.cancelAll(); result.success(null) }
                    "pendingReminders" -> result.success(notifications.pending())
                    "restoreReminders" -> { notifications.restore(); result.success(null) }
                    "permissionState" -> result.success(notifications.permissionState())
                    "activeNotificationIds" -> result.success(notifications.activeIds())
                    "showProgress" -> result.success(notifications.showProgress(call.arguments as Map<*, *>))
                    "cancelProgress" -> { notifications.cancelProgress(); result.success(null) }
                    "openSettings" -> { notifications.openSettings(call.argument<String>("kind")); result.success(null) }
                    "consumeLaunchPayload" -> {
                        result.success(intent?.getStringExtra(SystemNotifications.PAYLOAD))
                        intent?.removeExtra(SystemNotifications.PAYLOAD)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("notification_error", e.message ?: "Unable to update notification", null)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra(SystemNotifications.PAYLOAD)?.let {
            channel?.invokeMethod("openPayload", it)
            intent.removeExtra(SystemNotifications.PAYLOAD)
        }
    }
}
