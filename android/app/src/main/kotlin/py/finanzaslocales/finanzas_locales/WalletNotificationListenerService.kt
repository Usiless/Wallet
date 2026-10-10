package py.finanzaslocales.finanzas_locales

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

class WalletNotificationListenerService : NotificationListenerService() {
    companion object {
        var connectedInstance: WalletNotificationListenerService? = null
            private set
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        if (BuildConfig.DEVELOPER_TOOLS_ENABLED) connectedInstance = this
    }

    override fun onListenerDisconnected() {
        connectedInstance = null
        super.onListenerDisconnected()
    }

    override fun onDestroy() {
        if (connectedInstance === this) connectedInstance = null
        super.onDestroy()
    }

    fun readActiveWalletNotifications(): List<Map<String, Any?>> {
        check(BuildConfig.DEVELOPER_TOOLS_ENABLED) { "Herramientas de desarrollo desactivadas." }
        return (activeNotifications ?: emptyArray())
            .filter { NotificationQueue.defaultPackages.contains(it.packageName) }
            .sortedByDescending { it.postTime }
            .map { envelope(it, false).toFlutterMap() }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val isTest = BuildConfig.DEVELOPER_TOOLS_ENABLED && sbn.packageName == packageName && sbn.tag == "wallet_developer_test"
        val preferences = getSharedPreferences(NotificationQueue.preferencesName, Context.MODE_PRIVATE)
        if (!isTest && !preferences.getBoolean(NotificationQueue.enabledKey, false)) return
        val allowed = preferences.getStringSet(NotificationQueue.packagesKey, NotificationQueue.defaultPackages)
            ?: NotificationQueue.defaultPackages
        if (!isTest && (!allowed.contains(sbn.packageName) ||
            (!NotificationQueue.defaultPackages.contains(sbn.packageName) && !BuildConfig.DEVELOPER_TOOLS_ENABLED))) return

        val queue = NotificationQueue.read(preferences)
        val isUpdate = queue.any { it.optString("notificationKey") == sbn.key }
        val envelope = envelope(sbn, isUpdate)
        queue.add(envelope)
        val cutoff = System.currentTimeMillis() - 24L * 60L * 60L * 1000L
        val retained = queue.filter { it.optLong("postTime", 0L) >= cutoff }.takeLast(100)
        NotificationQueue.write(preferences, retained)
        NotificationQueue.onCaptured?.invoke()
        // Proposals are reviewed inside the app; no system review notification.
    }

    private fun envelope(sbn: StatusBarNotification, isUpdate: Boolean): JSONObject {
        val extras = sbn.notification.extras
        val isTest = BuildConfig.DEVELOPER_TOOLS_ENABLED && sbn.packageName == packageName && sbn.tag == "wallet_developer_test"
        val lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?.map { it.toString() } ?: emptyList()
        return JSONObject().apply {
            put("version", 1)
            put("captureId", java.util.UUID.randomUUID().toString())
            put("packageName", if (isTest) "com.google.android.apps.walletnfcrel" else sbn.packageName)
            put("isTest", isTest)
            put("notificationKey", sbn.key)
            put("id", sbn.id)
            put("tag", sbn.tag ?: JSONObject.NULL)
            put("postTime", sbn.postTime)
            put("title", extras.getCharSequence(if (isTest) "testMerchant" else Notification.EXTRA_TITLE)?.toString() ?: JSONObject.NULL)
            put("text", extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: JSONObject.NULL)
            put("bigText", extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: JSONObject.NULL)
            put("subText", extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: JSONObject.NULL)
            put("summaryText", extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT)?.toString() ?: JSONObject.NULL)
            put("textLines", JSONArray(lines))
            put("isUpdate", isUpdate)
        }
    }


}

internal object NotificationQueue {
    var onCaptured: (() -> Unit)? = null
    const val preferencesName = "notification_listener"
    const val enabledKey = "enabled"
    const val diagnosticKey = "diagnostic_mode"
    const val packagesKey = "allowed_packages"
    const val queueKey = "envelope_queue_v1"
    val defaultPackages = setOf("com.google.android.gms", "com.google.android.apps.walletnfcrel")

    fun read(preferences: SharedPreferences): MutableList<JSONObject> {
        val stored = preferences.getString(queueKey, "[]") ?: "[]"
        val json = if (stored.startsWith("v1:")) DeviceCrypto.decrypt(stored) else stored
        val array = JSONArray(json)
        if (!stored.startsWith("v1:")) {
            check(preferences.edit().putString(queueKey, DeviceCrypto.encrypt(json)).commit())
        }
        return (0 until array.length()).mapNotNull { array.optJSONObject(it) }.toMutableList()
    }

    fun write(preferences: SharedPreferences, values: List<JSONObject>) {
        check(preferences.edit().putString(queueKey, DeviceCrypto.encrypt(JSONArray(values).toString())).commit())
    }
}
