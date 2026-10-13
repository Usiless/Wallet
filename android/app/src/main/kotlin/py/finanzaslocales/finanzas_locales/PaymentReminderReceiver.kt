package py.finanzaslocales.finanzas_locales

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

/** No ledger access: this receiver can only display a previously reconciled reminder. */
class PaymentReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            if (intent.action == PaymentReminderAgenda.ALARM) {
                PaymentReminderAgenda.deliver(context, intent.getStringExtra("generation"), intent.getStringExtra("id"))
            } else {
                PaymentReminderAgenda.rebuild(context)
            }
        } catch (_: Exception) {
            // Fail closed if encrypted storage/Keystore is unavailable; next foreground reconcile retries.
        }
    }
}

internal object PaymentReminderAgenda {
    const val ALARM = "py.finanzaslocales.PAYMENT_REMINDER"
    const val OPEN = "py.finanzaslocales.OPEN_PAYMENT"
    const val CHANNEL = "payment_reminders_v1"
    const val EXPENSE_CHANNEL = "expense_check_v1"
    private fun preferences(c: Context) = c.getSharedPreferences("payment_reminders", Context.MODE_PRIVATE)
    private fun read(c: Context): JSONObject {
        val value = preferences(c).getString("encrypted", null) ?: return JSONObject().put("generation", "").put("requests", JSONArray()).put("delivered", JSONArray())
        return JSONObject(DeviceCrypto.decrypt(value))
    }
    private fun write(c: Context, state: JSONObject) {
        check(preferences(c).edit().putString("encrypted", DeviceCrypto.encrypt(state.toString())).commit())
    }
    private fun manager(c: Context) = c.getSystemService(NotificationManager::class.java)
    private fun channel(c: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            manager(c).createNotificationChannel(NotificationChannel(CHANNEL, "Pagos pendientes", NotificationManager.IMPORTANCE_DEFAULT))
            manager(c).createNotificationChannel(NotificationChannel(EXPENSE_CHANNEL, "Recordatorio de gastos", NotificationManager.IMPORTANCE_DEFAULT))
        }
    }
    fun permission(c: Context): Boolean {
        channel(c)
        return NotificationManagerCompat.from(c).areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 26 || manager(c).getNotificationChannel(CHANNEL).importance != NotificationManager.IMPORTANCE_NONE)
    }
    private fun entries(state: JSONObject): List<JSONObject> {
        val array = state.getJSONArray("requests")
        return (0 until array.length()).map { array.getJSONObject(it) }
    }
    private fun delivered(state: JSONObject): Set<String> {
        val array = state.getJSONArray("delivered")
        return (0 until array.length()).map { array.getString(it) }.toSet()
    }
    private fun millis(r: JSONObject): Long {
        val text = r.getString("localDateTime")
        require(text.matches(Regex("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}")))
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).apply {
            isLenient = false
            timeZone = TimeZone.getDefault()
        }
        return requireNotNull(format.parse(text)).time
    }
    private fun alarm(c: Context, generation: String, id: String): PendingIntent = PendingIntent.getBroadcast(c, 0,
        Intent(c, PaymentReminderReceiver::class.java).setAction(ALARM)
            .setData(Uri.parse("cabal-reminder://alarm/${Uri.encode(generation)}/${Uri.encode(id)}"))
            .putExtra("generation", generation).putExtra("id", id), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun entry(state: JSONObject, r: JSONObject) = PaymentReminderEntry(
        r.getString("id"),
        listOf("obligationId", "title", "body", "localDateTime", "revision", "channel").map { r.optString(it, "") },
        r.optString("generation", state.optString("generation", "")),
        millis(r),
    )

    @Synchronized fun replace(c: Context, requests: List<Map<String, Any?>>): Boolean {
        val unique = mutableSetOf<String>()
        val array = JSONArray()
        requests.forEach { value ->
            val r = JSONObject(value)
            val id = r.getString("id")
            require(id.isNotBlank() && id.length <= 512 && unique.add(id))
            require(r.getString("obligationId").isNotBlank() && r.getString("obligationId").length <= 160)
            require(r.getString("title").length <= 240 && r.getString("body").length <= 500)
            require(r.optString("channel", "payment") in setOf("payment", "expense"))
            millis(r) // Validate all requests before replacing the valid agenda.
            array.put(r)
        }
        require(requests.size <= 20000)
        val old = read(c)
        val generation = UUID.randomUUID().toString()
        val oldEntries = entries(old).map { entry(old, it) }
        val incoming = (0 until array.length()).map { entry(old, array.getJSONObject(it)) }
        val replacement = replacePaymentReminderEntries(oldEntries, incoming, delivered(old), System.currentTimeMillis(), generation)
        replacement.entries.forEachIndexed { index, value -> array.getJSONObject(index).put("generation", value.generation) }
        val state = JSONObject().put("generation", generation)
            .put("requests", array).put("delivered", JSONArray(replacement.delivered.toList()))
        // Persist before cancellation: queued broadcasts/taps for removed or edited entries fail closed.
        write(c, state)
        replacement.invalidated.forEach { r ->
            c.getSystemService(AlarmManager::class.java).cancel(alarm(c, r.generation, r.id))
            manager(c).cancel("payment:${r.id}", 0)
        }
        // Refresh the bounded future window without discarding a delayed, already due alarm.
        oldEntries.filter { it.at > System.currentTimeMillis() }.forEach { r ->
            c.getSystemService(AlarmManager::class.java).cancel(alarm(c, r.generation, r.id))
        }
        schedule(c, state)
        return permission(c)
    }
    private fun schedule(c: Context, state: JSONObject) {
        val done = delivered(state)
        if (!permission(c)) return
        // Bound outstanding alarms below Android's per-app limit. Each delivery fills the window.
        entries(state).filter { it.getString("id") !in done && millis(it) > System.currentTimeMillis() }
            .sortedBy { millis(it) }.take(400).forEach { r ->
            c.getSystemService(AlarmManager::class.java).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, millis(r), alarm(c, entry(state, r).generation, r.getString("id")))
        }
    }
    @Synchronized fun rebuild(c: Context) {
        val state = read(c)
        entries(state).forEach { r -> c.getSystemService(AlarmManager::class.java).cancel(alarm(c, entry(state, r).generation, r.getString("id"))) }
        schedule(c, state)
    }
    @Synchronized fun deliver(c: Context, generation: String?, id: String?) {
        val state = read(c)
        if (id == null || id in delivered(state)) return
        if (entries(state).none { it.getString("id") == id && entry(state, it).generation == generation } || !permission(c)) return
        val done = delivered(state)
        val byId = entries(state).associateBy { it.getString("id") }
        val due = byId.values.filter { it.getString("id") !in done && millis(it) <= System.currentTimeMillis() }
        val (notify, skipped) = collapseDailyBacklog(due.map { entry(state, it) }) { isDaily(byId.getValue(it.id)) }
        skipped.forEach { state.getJSONArray("delivered").put(it) }
        notify.forEach { e ->
            val r = byId.getValue(e.id)
            // A new daily notice replaces yesterday's unanswered one.
            if (isDaily(r)) byId.values.filter { isDaily(it) && it.getString("id") != e.id }
                .forEach { manager(c).cancel("payment:${it.getString("id")}", 0) }
            notifyOne(c, state, e.generation, r)
        }
        if (notify.isEmpty() && skipped.isNotEmpty()) write(c, state)
        schedule(c, state)
    }
    private fun isDaily(r: JSONObject) = r.optString("channel") == "expense"
    private fun notifyOne(c: Context, state: JSONObject, generation: String?, r: JSONObject) {
        val id = r.getString("id")
        val contentIntent = Intent(c, MainActivity::class.java).setAction(OPEN)
            .setData(Uri.parse("cabal-reminder://open/${Uri.encode(generation)}/${Uri.encode(id)}"))
            .putExtra("reminderGeneration", generation).putExtra("reminderId", id)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pending = PendingIntent.getActivity(c, 0, contentIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val channelId = if (isDaily(r)) EXPENSE_CHANNEL else CHANNEL
        val notification = NotificationCompat.Builder(c, channelId)
            .setSmallIcon(android.R.drawable.ic_popup_reminder).setContentTitle(r.getString("title"))
            .setContentText(r.getString("body")).setContentIntent(pending).setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE).build()
        // Persist before notify: process death cannot produce a second delivery.
        state.getJSONArray("delivered").put(id)
        write(c, state)
        try { manager(c).notify("payment:$id", 0, notification) } catch (_: SecurityException) { /* revoked concurrently */ }
    }
    @Synchronized fun consume(c: Context, intent: Intent?): String? {
        if (intent?.action != OPEN) return null
        val state = read(c)
        val generation = intent.getStringExtra("reminderGeneration")
        val id = intent.getStringExtra("reminderId")
        intent.removeExtra("reminderGeneration")
        intent.removeExtra("reminderId")
        return entries(state).firstOrNull { it.getString("id") == id && entry(state, it).generation == generation }?.getString("obligationId")
    }
}
