package com.nus.clearhear

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

class MainActivity: FlutterActivity() {
    private val modelAssetChannel = "clearhear/model_assets"
    private val foregroundServiceChannel = "clearhear/foreground_service"
    private val audioInterruptionChannel = "clearhear/audio_interruption"

    private var audioManager: AudioManager? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var interruptionMethodChannel: MethodChannel? = null

    private val audioFocusListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_LOSS,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                interruptionMethodChannel?.invokeMethod("onInterruptionBegan", null)
            }
            AudioManager.AUDIOFOCUS_GAIN -> {
                interruptionMethodChannel?.invokeMethod("onInterruptionEnded", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            modelAssetChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAssetBundleDir" -> {
                    val bundleDir = FlutterInjector.instance().flutterLoader().findAppBundlePath()
                    result.success(bundleDir)
                }
                "copyAssetToFile" -> {
                    val assetPath = call.argument<String>("assetPath")
                    val targetPath = call.argument<String>("targetPath")
                    if (assetPath.isNullOrBlank() || targetPath.isNullOrBlank()) {
                        result.error(
                            "invalid_arguments",
                            "assetPath and targetPath are required",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val copied = copyAssetToFile(assetPath, targetPath)
                        result.success(copied)
                    } catch (error: Exception) {
                        result.error(
                            "copy_failed",
                            error.message,
                            null,
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            foregroundServiceChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val intent = Intent(this, TranscriptionForegroundService::class.java)
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: android.app.ForegroundServiceStartNotAllowedException) {
                        result.error("start_not_allowed", e.message, null)
                    } catch (e: SecurityException) {
                        result.error("security_exception", e.message, null)
                    }
                }
                "stop" -> {
                    val intent = Intent(this, TranscriptionForegroundService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        interruptionMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            audioInterruptionChannel,
        )
        interruptionMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startListening" -> {
                    audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val audioAttributes = AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                        audioFocusRequest = AudioFocusRequest.Builder(
                            AudioManager.AUDIOFOCUS_GAIN
                        )
                            .setAudioAttributes(audioAttributes)
                            .setOnAudioFocusChangeListener(audioFocusListener)
                            .build()
                        val granted = audioManager?.requestAudioFocus(audioFocusRequest!!)
                        result.success(granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED)
                    } else {
                        @Suppress("DEPRECATION")
                        val granted = audioManager?.requestAudioFocus(
                            audioFocusListener,
                            AudioManager.STREAM_VOICE_CALL,
                            AudioManager.AUDIOFOCUS_GAIN
                        )
                        result.success(granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED)
                    }
                }
                "stopListening" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        audioFocusRequest?.let {
                            audioManager?.abandonAudioFocusRequest(it)
                        }
                    } else {
                        @Suppress("DEPRECATION")
                        audioManager?.abandonAudioFocus(audioFocusListener)
                    }
                    audioFocusRequest = null
                    audioManager = null
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let {
                audioManager?.abandonAudioFocusRequest(it)
            }
        } else {
            @Suppress("DEPRECATION")
            audioManager?.abandonAudioFocus(audioFocusListener)
        }
        super.onDestroy()
    }

    private fun copyAssetToFile(assetPath: String, targetPath: String): Boolean {
        val flutterLoader = FlutterInjector.instance().flutterLoader()
        val targetFile = File(targetPath)
        targetFile.parentFile?.mkdirs()

        val bundlePath = flutterLoader.findAppBundlePath()
        val bundleFile = File(bundlePath, assetPath)
        if (bundleFile.exists() && bundleFile.length() > 0) {
            bundleFile.inputStream().use { input ->
                FileOutputStream(targetFile, false).use { output ->
                    val buffer = ByteArray(8 * 1024)
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        output.write(buffer, 0, read)
                    }
                    output.flush()
                }
            }
            return targetFile.exists() && targetFile.length() > 0
        }

        val lookupKey = flutterLoader.getLookupKeyForAsset(assetPath)
        try {
            applicationContext.assets.open(lookupKey).use { input ->
                FileOutputStream(targetFile, false).use { output ->
                    val buffer = ByteArray(8 * 1024)
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        output.write(buffer, 0, read)
                    }
                    output.flush()
                }
            }
        } catch (error: IOException) {
            throw error
        }

        return targetFile.exists() && targetFile.length() > 0
    }
}
