package com.jellyfin.native_video_downloader

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * native_video_downloader 的 Android 插件入口。
 *
 * 这个类只负责 Flutter Channel：
 * - MethodChannel 接收 Flutter 发来的命令。
 * - EventChannel 把 Android 下载进度推回 Flutter。
 *
 * 真实下载逻辑放在 NativeDownloadManager 里。
 */
class NativeVideoDownloaderPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var applicationContext: Context

    private val downloadManager = NativeDownloadManager()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext

        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "native_video_downloader")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "native_video_downloader/events"
        )
        eventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }

            "startDownload" -> {
                val url = call.argument<String>("url")
                if (url.isNullOrBlank()) {
                    result.error("missing_url", "startDownload requires a non-empty url", null)
                    return
                }

                val taskId = downloadManager.startDownload(
                    url = url,
                    cacheDir = applicationContext.cacheDir,
                    onProgress = ::sendDownloadEvent
                )
                result.success("$taskId|$url")
            }

            "deleteDownload" -> {
                val taskId = call.argument<String>("taskId")
                if (taskId.isNullOrBlank()) {
                    result.error("missing_task_id", "deleteDownload requires a non-empty taskId", null)
                    return
                }

                // 这里先只把 Flutter 发来的删除信号交给原生管理器。
                // 后面接 Room 和文件管理时，再在 NativeDownloadManager 里删除数据库记录和本地视频文件。
                val accepted = downloadManager.deleteDownload(taskId)
                result.success(accepted)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun sendDownloadEvent(event: Map<String, Any>) {
        mainHandler.post {
            eventSink?.success(event)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        eventSink = null
        eventChannel.setStreamHandler(null)
        channel.setMethodCallHandler(null)
    }
}
