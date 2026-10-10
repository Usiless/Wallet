package py.finanzaslocales.finanzas_locales

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "py.finanzaslocales.IGNORE_CAPTURED") return
        val key = intent.getStringExtra("notificationKey") ?: return
        val preferences = context.getSharedPreferences(NotificationQueue.preferencesName, Context.MODE_PRIVATE)
        val remaining = NotificationQueue.read(preferences)
            .filterNot { it.optString("notificationKey") == key }
        NotificationQueue.write(preferences, remaining)
        context.getSystemService(NotificationManager::class.java).cancel(key.hashCode())
    }
}
