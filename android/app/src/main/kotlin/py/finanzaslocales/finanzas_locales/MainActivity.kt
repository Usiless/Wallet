package py.finanzaslocales.finanzas_locales

import android.Manifest
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val channelName = "finanzas_locales/notification_listener"
    private val notificationPermissionRequest = 701
    private var initialAction: String? = null
    private var reminderWorker: ReminderWorker? = null
    private var pendingNotificationPermission: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        initialAction = intent?.action
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        initialAction = intent.action
        if (intent.action == PaymentReminderAgenda.OPEN) NotificationQueue.onCaptured?.invoke()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "finanzas_locales/security").setMethodCallHandler { call, result ->
            when (call.method) {
                "databaseKey" -> try { result.success(DeviceCrypto.databaseKey(this)) }
                    catch (_: Exception) { result.error("storage_key_unavailable", "No se pudo abrir el almacenamiento protegido.", null) }
                "deriveBackupKey" -> {
                    val password = call.argument<String>("password")
                    val salt = call.argument<ByteArray>("salt")
                    if (password == null || salt == null || salt.size != 16) {
                        result.error("invalid_key_parameters", "Parámetros de backup inválidos.", null)
                    } else Thread {
                        try {
                            val derived = DeviceCrypto.deriveBackupKey(password, salt)
                            runOnUiThread { result.success(derived) }
                        } catch (_: Exception) {
                            runOnUiThread { result.error("backup_key_failed", "No se pudo descifrar el backup.", null) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "finanzas_locales/updater").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "canInstall" -> result.success(UpdateInstaller.canInstall(this))
                    "openInstallSettings" -> {
                        UpdateInstaller.openInstallSettings(this)
                        result.success(null)
                    }
                    "install" -> {
                        UpdateInstaller.install(this, call.argument<String>("path") ?: "")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (failure: UpdateInstaller.Failure) {
                result.error(failure.code, failure.message, null)
            }
        }
        val reminderWorker = ReminderWorker { reply -> runOnUiThread(reply) }
        this.reminderWorker = reminderWorker
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "finanzas_locales/payment_reminders").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "permission" -> result.success(PaymentReminderAgenda.permission(this))
                    "requestPermission" -> requestOwnNotificationPermission(object : MethodChannel.Result {
                        override fun success(value: Any?) { result.success(PaymentReminderAgenda.permission(this@MainActivity)) }
                        override fun error(code: String, message: String?, details: Any?) { result.error(code, message, details) }
                        override fun notImplemented() { result.notImplemented() }
                    })
                    "replaceSchedule" -> {
                        val requests = call.argument<List<Map<String, Any?>>>("requests") ?: emptyList()
                        reminderWorker.execute({ PaymentReminderAgenda.replace(this, requests) }) { outcome ->
                            outcome.fold(
                                onSuccess = { result.success(it) },
                                onFailure = { result.error("reminder_schedule_failed", "No se pudieron actualizar los recordatorios.", null) },
                            )
                        }
                    }
                    "consumeOpenAction" -> {
                        // Capture this intent before a subsequent onNewIntent replaces it.
                        val openIntent = intent
                        reminderWorker.execute({ PaymentReminderAgenda.consume(this, openIntent) }) { outcome ->
                            outcome.fold(
                                onSuccess = { result.success(it) },
                                onFailure = { result.error("reminder_schedule_failed", "No se pudieron actualizar los recordatorios.", null) },
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("reminder_schedule_failed", "No se pudieron actualizar los recordatorios.", null)
            }
        }
        val captureChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        NotificationQueue.onCaptured = { captureChannel.invokeMethod("notificationCaptured", null) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            val preferences = getSharedPreferences(NotificationQueue.preferencesName, MODE_PRIVATE)
            when (call.method) {
                "isAccessGranted" -> result.success(isNotificationAccessGranted())
                "openAccessSettings" -> {
                    openNotificationAccessSettings()
                    result.success(null)
                }
                "requestOwnNotificationPermission" -> requestOwnNotificationPermission(result)
                "readActiveWalletNotifications" -> {
                    if (!BuildConfig.DEVELOPER_TOOLS_ENABLED) {
                        result.error("developer_tools_disabled", "Herramientas de desarrollo desactivadas.", null)
                    } else if (!isNotificationAccessGranted()) {
                        result.error("notification_access_required", "Concedé acceso a notificaciones en los ajustes de Android.", null)
                    } else {
                        val listener = WalletNotificationListenerService.connectedInstance
                        if (listener == null) {
                            android.service.notification.NotificationListenerService.requestRebind(
                                ComponentName(this, WalletNotificationListenerService::class.java),
                            )
                            result.error("listener_not_connected", "El lector aún no está conectado. Esperá unos segundos y volvé a consultar.", null)
                        } else {
                            try {
                                result.success(listener.readActiveWalletNotifications())
                            } catch (_: Exception) {
                                result.error("active_notifications_unavailable", "Android no permitió consultar las notificaciones. Revisá el acceso y volvé a intentar.", null)
                            }
                        }
                    }
                }
                "sendTestNotification" -> {
                    if (!BuildConfig.DEVELOPER_TOOLS_ENABLED) {
                        result.error("developer_tools_disabled", "Herramientas de desarrollo desactivadas.", null)
                    } else if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        result.error("notification_permission_required", "Concedé permiso para mostrar notificaciones de prueba.", null)
                    } else {
                        val merchant = call.argument<String>("merchant")?.trim() ?: ""
                        val alias = call.argument<String>("alias") ?: ""
                        val amount = call.argument<Number>("amount")?.toLong() ?: 0
                        if (merchant.isEmpty() || merchant.length > 160 || !alias.matches(Regex("[0-9]{4,6}")) || amount <= 0) {
                            result.error("invalid_test_notification", "Revisá comercio, identificador e importe.", null)
                        } else {
                            val manager = getSystemService(android.app.NotificationManager::class.java)
                            val channelId = "wallet_tests"
                            if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(android.app.NotificationChannel(channelId, "Pruebas de Wallet", android.app.NotificationManager.IMPORTANCE_DEFAULT))
                            val notification = androidx.core.app.NotificationCompat.Builder(this, channelId)
                                .setSmallIcon(android.R.drawable.ic_dialog_info)
                                .setContentTitle("PRUEBA Wallet: $merchant")
                                .setContentText("PYG $amount · ••$alias")
                                .addExtras(android.os.Bundle().apply { putString("testMerchant", merchant) })
                                .setTimeoutAfter(60000)
                                .build()
                            manager.notify("wallet_developer_test", (System.nanoTime() and 0x7fffffff).toInt(), notification)
                            result.success(null)
                        }
                    }
                }
                "configure" -> {
                    val packages = call.argument<List<String>>("allowedPackages") ?: emptyList()
                    preferences.edit()
                        .putBoolean(NotificationQueue.enabledKey, call.argument<Boolean>("enabled") == true)
                        .putBoolean(NotificationQueue.diagnosticKey, BuildConfig.DEVELOPER_TOOLS_ENABLED && call.argument<Boolean>("diagnosticMode") == true)
                        .putStringSet(NotificationQueue.packagesKey, packages.filter { NotificationQueue.defaultPackages.contains(it) || (BuildConfig.DEVELOPER_TOOLS_ENABLED && it == "com.google.android.apps.messaging") }.toSet())
                        .apply()
                    result.success(null)
                }
                "queuedEnvelopes" -> {
                    val queue = NotificationQueue.read(preferences)
                    queue.forEach { if (!it.has("captureId")) it.put("captureId", java.util.UUID.randomUUID().toString()) }
                    NotificationQueue.write(preferences, queue)
                    val visible = queue.filter {
                        BuildConfig.DEVELOPER_TOOLS_ENABLED || (!it.optBoolean("isTest", false) &&
                            NotificationQueue.defaultPackages.contains(it.optString("packageName")))
                    }
                    if (!BuildConfig.DEVELOPER_TOOLS_ENABLED) NotificationQueue.write(preferences, visible)
                    result.success(visible.map { it.toFlutterMap() })
                }
                "acknowledgeEnvelope" -> {
                    val captureId = call.argument<String>("captureId")
                    if (captureId != null) NotificationQueue.write(preferences,
                        NotificationQueue.read(preferences).filter { it.optString("captureId") != captureId })
                    result.success(null)
                }
                "clearCapturedEvents" -> {
                    NotificationQueue.write(preferences, emptyList())
                    result.success(null)
                }
                "getInitialAction" -> {
                    val action = initialAction
                    initialAction = null
                    result.success(action)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        NotificationQueue.onCaptured = null
        reminderWorker?.close()
        reminderWorker = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun requestOwnNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        if (pendingNotificationPermission != null) {
            result.error("permission_request_active", "Ya hay una solicitud de permiso activa.", null)
            return
        }
        pendingNotificationPermission = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationPermissionRequest)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notificationPermissionRequest) {
            pendingNotificationPermission?.success(
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED,
            )
            pendingNotificationPermission = null
        }
    }

    private fun isNotificationAccessGranted(): Boolean {
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        val component = ComponentName(this, WalletNotificationListenerService::class.java)
        return enabled.split(':').any { ComponentName.unflattenFromString(it) == component }
    }

    private fun openNotificationAccessSettings() {
        val detailIntent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).apply {
            putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                ComponentName(this@MainActivity, WalletNotificationListenerService::class.java).flattenToString())
        }
        try {
            startActivity(detailIntent)
        } catch (_: Exception) {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        }
    }
}

internal fun JSONObject.toFlutterMap(): Map<String, Any?> {
    val output = mutableMapOf<String, Any?>()
    keys().forEach { key ->
        output[key] = when (val value = opt(key)) {
            JSONObject.NULL -> null
            is JSONArray -> (0 until value.length()).map { value.opt(it)?.toString() }
            is JSONObject -> value.toFlutterMap()
            else -> value
        }
    }
    return output
}
