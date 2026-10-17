package com.lessonsearch.lesson_search

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import org.json.JSONObject

/** System-owned one-shot alarms; scheduling never requires a resident Dart process. */
class SystemNotifications(private val context: Context) {
    companion object {
        const val PAYLOAD = "lesson_search.notification_payload"
        private const val STORE = "lesson_search_system_reminders"
        private const val REMINDERS = "reminders"
        private const val REMINDER_CHANNEL = "duty_reminder_v2"
        private const val PROGRESS_CHANNEL = "attendance_progress"
        private const val PROGRESS_ID = 2147483000
    }

    private val manager = context.getSystemService(NotificationManager::class.java)
    private val alarms = context.getSystemService(AlarmManager::class.java)
    private val prefs = context.getSharedPreferences(STORE, Context.MODE_PRIVATE)

    private fun saved(): JSONObject = try { JSONObject(prefs.getString(REMINDERS, "{}") ?: "{}") }
        catch (_: Exception) { JSONObject() }

    private fun save(value: JSONObject) { prefs.edit().putString(REMINDERS, value.toString()).commit() }

    private fun enabled(): Boolean = manager.areNotificationsEnabled() &&
        (Build.VERSION.SDK_INT < 33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED)

    private fun exact(): Boolean = Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()

    fun permissionState(): Map<String, Any> {
        val promoted = if (Build.VERSION.SDK_INT >= 36) {
            try { manager.javaClass.getMethod("canPostPromotedNotifications").invoke(manager) as Boolean }
            catch (_: Exception) { false }
        } else false
        return mapOf("notificationsEnabled" to enabled(), "exactAlarms" to exact(),
            "liveUpdatesSupported" to (Build.VERSION.SDK_INT >= 36), "liveUpdatesEnabled" to promoted)
    }

    private fun channels() {
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(REMINDER_CHANNEL, "查课提醒", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "在计划上课前提醒查课"
                enableVibration(true)
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            })
            manager.createNotificationChannel(NotificationChannel(PROGRESS_CHANNEL, "正在进行的查课", NotificationManager.IMPORTANCE_LOW).apply {
                description = "显示当前查课进度，点按可继续任务"
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            })
        }
    }

    private fun pendingIntent(id: Int): PendingIntent = PendingIntent.getBroadcast(context, id,
        Intent(context, DutyReminderReceiver::class.java).putExtra("id", id),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun contentIntent(id: Int, payload: String): PendingIntent = PendingIntent.getActivity(context, id,
        Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(PAYLOAD, payload)
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    @Synchronized
    fun schedule(arguments: Map<*, *>): Map<String, String> {
        val id = (arguments["id"] as Number).toInt()
        require(id in 1 until PROGRESS_ID) { "Invalid reminder id" }
        val time = (arguments["scheduledAt"] as Number).toLong()
        if (time <= System.currentTimeMillis()) {
            cancel(id)
            return mapOf("status" to "elapsed")
        }
        channels()
        val entry = JSONObject().apply {
            put("id", id); put("scheduledAt", time)
            put("title", arguments["title"] as? String ?: "查课提醒")
            put("body", arguments["body"] as? String ?: "")
            put("payload", arguments["payload"] as? String ?: "")
        }
        val stored = saved()
        stored.put(id.toString(), entry)
        save(stored)
        // Preserve user intent for the next launch/permission reconciliation, but do not claim delivery.
        if (!enabled()) {
            alarms.cancel(pendingIntent(id))
            return mapOf("status" to "permissionDenied")
        }
        return try {
            val isExact = exact()
            if (isExact) alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pendingIntent(id))
            else alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pendingIntent(id))
            mapOf("status" to if (isExact) "scheduledExact" else "scheduledInexact")
        } catch (_: SecurityException) {
            // Permission can change between the check and the schedule call.
            try {
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pendingIntent(id))
                mapOf("status" to "scheduledInexact")
            } catch (e: Exception) { mapOf("status" to "failed", "error" to (e.message ?: "调度失败")) }
        } catch (e: Exception) { mapOf("status" to "failed", "error" to (e.message ?: "调度失败")) }
    }

    @Synchronized
    fun cancel(id: Int) {
        alarms.cancel(pendingIntent(id))
        manager.cancel(id)
        val value = saved(); value.remove(id.toString()); save(value)
    }

    fun cancelProgress() { manager.cancel(PROGRESS_ID) }

    fun activeIds(): List<Int> = manager.activeNotifications.map { it.id }

    @Synchronized
    fun cancelAll() {
        saved().keys().asSequence().toList().forEach { key -> key.toIntOrNull()?.let { alarms.cancel(pendingIntent(it)); manager.cancel(it) } }
        save(JSONObject())
        cancelProgress()
    }

    fun pending(): List<Map<String, Any>> {
        val value = saved()
        return value.keys().asSequence().mapNotNull { key -> value.optJSONObject(key)?.let {
            mapOf("id" to it.getInt("id"), "title" to it.optString("title"),
                "body" to it.optString("body"), "payload" to it.optString("payload"))
        } }.toList()
    }

    @Synchronized
    fun restore() {
        val value = saved()
        value.keys().asSequence().toList().forEach { key -> value.optJSONObject(key)?.let { entry ->
            if (entry.optLong("scheduledAt") <= System.currentTimeMillis()) cancel(entry.getInt("id"))
            else schedule(mapOf("id" to entry.getInt("id"), "scheduledAt" to entry.getLong("scheduledAt"),
                "title" to entry.optString("title"), "body" to entry.optString("body"), "payload" to entry.optString("payload")))
        } }
    }

    @Synchronized
    fun deliver(id: Int) {
        val value = saved()
        val entry = value.optJSONObject(id.toString()) ?: return
        value.remove(id.toString()); save(value)
        if (!enabled()) return
        // Never show a reminder hours late after an aggressive OEM suspended the receiver.
        if (System.currentTimeMillis() - entry.optLong("scheduledAt") > 15 * 60 * 1000) return
        channels()
        val builder = builder(REMINDER_CHANNEL).setSmallIcon(R.drawable.ic_stat_check)
            .setContentTitle(entry.optString("title")).setContentText(entry.optString("body"))
            .setStyle(Notification.BigTextStyle().bigText(entry.optString("body")))
            .setAutoCancel(true).setCategory(Notification.CATEGORY_EVENT)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setContentIntent(contentIntent(id, entry.optString("payload")))
        manager.notify(id, builder.build())
    }

    @Suppress("DEPRECATION")
    private fun builder(channel: String): Notification.Builder = if (Build.VERSION.SDK_INT >= 26)
        Notification.Builder(context, channel) else Notification.Builder(context)

    fun showProgress(arguments: Map<*, *>): Boolean {
        if (!enabled()) return false
        channels()
        val total = (arguments["total"] as? Number)?.toInt()?.coerceAtLeast(0) ?: 0
        val processed = ((arguments["processed"] as? Number)?.toInt() ?: 0).coerceIn(0, total.coerceAtLeast(0))
        val taskId = arguments["taskId"] as? String ?: return false
        val title = arguments["title"] as? String ?: "查课进行中"
        val text = "已处理 $processed / $total 人 · 点按继续"
        val builder = builder(PROGRESS_CHANNEL).setSmallIcon(R.drawable.ic_stat_check)
            .setContentTitle(title).setContentText(text).setOngoing(true).setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC).setCategory(Notification.CATEGORY_PROGRESS)
            .setProgress(total.coerceAtLeast(1), processed, total == 0)
            .setContentIntent(contentIntent(PROGRESS_ID, "task:$taskId"))
        if (Build.VERSION.SDK_INT >= 36) {
            builder.extras.putBoolean("android.requestPromotedOngoing", true)
            // Uses reflection so older Android runtimes never resolve a new API call.
            try { builder.javaClass.getMethod("setRequestPromotedOngoing", Boolean::class.javaPrimitiveType).invoke(builder, true) }
            catch (_: Exception) { /* Standard ongoing notification remains available. */ }
            try { builder.javaClass.getMethod("setShortCriticalText", String::class.java).invoke(builder, "$processed/$total") }
            catch (_: Exception) { }
        }
        manager.notify(PROGRESS_ID, builder.build())
        return true
    }

    fun openSettings(kind: String?) {
        val action = when {
            kind == "exact" && Build.VERSION.SDK_INT >= 31 -> Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM
            kind == "live" && Build.VERSION.SDK_INT >= 36 -> "android.settings.APP_NOTIFICATION_PROMOTION_SETTINGS"
            else -> Settings.ACTION_APP_NOTIFICATION_SETTINGS
        }
        val intent = Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        if (kind == "exact") intent.data = Uri.parse("package:${context.packageName}")
        try { context.startActivity(intent) } catch (_: Exception) {
            context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }
}

class DutyReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try { SystemNotifications(context).deliver(intent.getIntExtra("id", -1)) }
        catch (_: Exception) { /* A disabled permission must never crash a broadcast receiver. */ }
    }
}

class DutyReminderRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try { SystemNotifications(context).restore() } catch (_: Exception) { }
    }
}
