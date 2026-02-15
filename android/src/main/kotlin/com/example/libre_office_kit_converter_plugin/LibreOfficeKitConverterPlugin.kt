package com.example.libre_office_kit_converter_plugin

import LibreOfficeKitApi
import android.app.Activity
import android.content.Context
import android.content.res.AssetManager
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.core.content.edit
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.launch
import org.libreoffice.kit.LibreOfficeKit
import org.libreoffice.kit.Office
import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.channels.Channels
import java.nio.channels.FileChannel
import java.nio.channels.ReadableByteChannel
import java.util.concurrent.Executors

private const val ASSETS_EXTRACTED_PREFS_KEY = "LOK_ASSETS_EXTRACTED_PREFS_KEY"

/** LibreOfficeKitConverterPlugin */
class LibreOfficeKitConverterPlugin :
    FlutterPlugin,
    LibreOfficeKitApi, ActivityAware {
    private var context: Context? = null
    private var activity: Activity? = null
    private var office: Office? = null

    private val executor = Executors.newSingleThreadExecutor { it ->
        Thread(it, "LOK")
    }.asCoroutineDispatcher()
    private val coroutineScope = CoroutineScope(SupervisorJob() + executor)

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        this.activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        this.activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        this.activity = null
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        LibreOfficeKitApi.setUp(flutterPluginBinding.binaryMessenger, this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        office?.destroy()
        office = null
    }

    private fun copyAsset(
        assetManager: AssetManager,
        fromAssetPath: String,
        toPath: String
    ): Boolean {
        var source: ReadableByteChannel? = null
        var dest: FileChannel? = null
        try {
            try {
                source = Channels.newChannel(assetManager.open(fromAssetPath))
                dest = FileOutputStream(toPath).channel
                var bytesTransferred: Long = 0
                // might not copy all at once, so make sure everything gets copied...
                val buffer = ByteBuffer.allocate(4096)
                while (source!!.read(buffer) > 0) {
                    buffer.flip()
                    bytesTransferred += dest.write(buffer).toLong()
                    buffer.clear()
                }
                return true
            } finally {
                dest?.close()
                source?.close()
            }
        } catch (e: FileNotFoundException) {
            return false
        } catch (e: IOException) {
            return false
        }
    }

    private fun copyFromAssets(
        assetManager: AssetManager,
        fromAssetPath: String, targetDir: String
    ): Boolean {
        try {
            val files = assetManager.list(fromAssetPath)

            var res = true
            for (file in files!!) {
                val dirOrFile = assetManager.list("$fromAssetPath/$file")
                if (dirOrFile!!.size == 0) {
                    // noinspection ResultOfMethodCallIgnored
                    File(targetDir).mkdirs()
                    res = res and copyAsset(
                        assetManager,
                        "$fromAssetPath/$file",
                        "$targetDir/$file"
                    )
                } else res = res and copyFromAssets(
                    assetManager,
                    "$fromAssetPath/$file",
                    "$targetDir/$file"
                )
            }
            return res
        } catch (e: java.lang.Exception) {
            e.printStackTrace()
            return false
        }
    }

    @RequiresApi(Build.VERSION_CODES.GINGERBREAD)
    override fun initialize(callback: (Result<Unit>) -> Unit) {
        coroutineScope.launch {
            try {
                if (activity == null) {
                    callback(Result.failure(ActivityNotFoundException()))
                    return@launch
                }

                val sPrefs = activity!!.getPreferences(Context.MODE_PRIVATE)
                val isInitialized = sPrefs.getBoolean(ASSETS_EXTRACTED_PREFS_KEY, false)
                if (!isInitialized) {
                    copyFromAssets(activity!!.assets, "unpack", activity!!.applicationInfo.dataDir)
                    sPrefs.edit {
                        putBoolean(ASSETS_EXTRACTED_PREFS_KEY, true)
                        apply()
                    }
                }

                LibreOfficeKit.init(activity)
                office = Office(LibreOfficeKit.getLibreOfficeKitHandle())
                callback(Result.success(Unit))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }

    override fun convert(
        filePath: String,
        outputFormat: String,
        outputFilePath: String?,
        outputFileName: String?,
        filterOptions: String?,
        callback: (Result<String>) -> Unit
    ) {
        coroutineScope.launch {
            if (office == null) {
                callback(Result.failure(LokInitializationException("Office instance not found. Maybe you forgot to call init method")))
                return@launch
            }
            if (context == null) {
                callback(Result.failure(MissingApplicationContextException()))
                return@launch
            }
            try {
                var file: File

                if (outputFilePath != null) {
                    file = File(outputFilePath)
                } else {
                    if (outputFileName != null) {
                        val outDir = context!!.cacheDir
                        val name = "$outputFileName.$outputFormat"
                        file = File(outDir, name)
                    } else {
                        file = File.createTempFile("LibreOfficeConverted", ".$outputFormat")
                    }
                }

                val document = office!!.documentLoad(filePath)
                document.saveAs(file.absolutePath, outputFormat, filterOptions ?: "")
                document.destroy()

                callback(Result.success(file.absolutePath))
            } catch (e: Exception) {
                callback(Result.failure(e))
            }
        }
    }
}

class ActivityNotFoundException() : Exception()
class MissingApplicationContextException() : Exception()
class LokInitializationException(message: String) : Exception(message)
