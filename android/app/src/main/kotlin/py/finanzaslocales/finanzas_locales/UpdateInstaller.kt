package py.finanzaslocales.finanzas_locales

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File

/** Permiso de instalación del APK descargado por el actualizador. */
object UpdateInstaller {
    class Failure(val code: String, message: String) : Exception(message)

    private const val APK_MIME = "application/vnd.android.package-archive"
    private const val INVALID_PATH = "El archivo de actualización no es válido."

    fun canInstall(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || context.packageManager.canRequestPackageInstalls()

    fun openInstallSettings(context: Context) {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${context.packageName}"))
        } else {
            Intent(Settings.ACTION_SECURITY_SETTINGS)
        }
        try {
            context.startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            throw Failure("installer_unavailable", "No se pudieron abrir los ajustes de Android.")
        }
    }

    fun install(context: Context, path: String) {
        val updatesDir = try {
            File(context.cacheDir, "updates").canonicalFile
        } catch (_: Exception) {
            throw Failure("invalid_apk_path", INVALID_PATH)
        }
        val apk = try {
            File(path).canonicalFile
        } catch (_: Exception) {
            throw Failure("invalid_apk_path", INVALID_PATH)
        }
        if (!apk.isFile || !apk.name.endsWith(".apk") || !apk.path.startsWith(updatesDir.path + File.separator)) {
            throw Failure("invalid_apk_path", INVALID_PATH)
        }
        if (!canInstall(context)) {
            throw Failure("install_not_allowed", "Android no permite instalar Cabal desde esta fuente.")
        }
        val uri = try {
            FileProvider.getUriForFile(context, "${context.packageName}.updater.fileprovider", apk)
        } catch (_: IllegalArgumentException) {
            throw Failure("invalid_apk_path", INVALID_PATH)
        }
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, APK_MIME)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            throw Failure("installer_unavailable", "No hay un instalador disponible en este dispositivo.")
        }
    }
}
