package com.parchipocket.app.parchipocket

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.StatFs
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val updateChannelName = "com.parchipocket.app/update_installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getUpdateDirectory" -> {
                        val directory = File(cacheDir, "parchipocket-updates/apk")
                        if (!directory.exists() && !directory.mkdirs()) {
                            result.error("update_storage_unavailable", "Update storage is unavailable.", null)
                        } else {
                            result.success(directory.canonicalPath)
                        }
                    }
                    "getAvailableStorageBytes" -> {
                        result.success(StatFs(cacheDir.absolutePath).availableBytes)
                    }
                    "getInstalledVersion" -> {
                        val info = packageManager.getPackageInfo(packageName, 0)
                        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            info.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            info.versionCode.toLong()
                        }
                        result.success(
                            mapOf(
                                "versionName" to (info.versionName ?: ""),
                                "versionCode" to versionCode.toInt()
                            )
                        )
                    }
                    "canRequestPackageInstalls" -> {
                        result.success(
                            Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                                packageManager.canRequestPackageInstalls()
                        )
                    }
                    "openInstallPermissionSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(
                                android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                        }
                        result.success(true)
                    }
                    "installVerifiedApk" -> installVerifiedApk(call.argument<String>("path"), result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun installVerifiedApk(path: String?, result: MethodChannel.Result) {
        if (path.isNullOrBlank()) {
            result.error("invalid_update_file", "The verified update file is unavailable.", null)
            return
        }
        try {
            val allowedDirectory = File(cacheDir, "parchipocket-updates/apk").canonicalFile
            val apk = File(path).canonicalFile
            if (!apk.path.startsWith(allowedDirectory.path + File.separator) ||
                !apk.isFile || apk.length() <= 0L || !apk.name.endsWith(".apk", ignoreCase = true)
            ) {
                result.error("invalid_update_file", "Only a verified app-private APK can be opened.", null)
                return
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                !packageManager.canRequestPackageInstalls()
            ) {
                result.error(
                    "install_permission_required",
                    "Allow ParchiPocket to install this update in Android settings.",
                    null
                )
                return
            }
            val contentUri = FileProvider.getUriForFile(
                this,
                "$packageName.updateprovider",
                apk
            )
            val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
                setDataAndType(contentUri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (_: Exception) {
            result.error("installer_unavailable", "Android could not open the package installer.", null)
        }
    }
}
