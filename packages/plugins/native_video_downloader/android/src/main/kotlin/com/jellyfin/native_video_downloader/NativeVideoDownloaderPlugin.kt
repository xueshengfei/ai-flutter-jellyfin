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
 * 真正下载逻辑放在 NativeDownloadManager 里。
 */
class NativeVideoDownloaderPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var applicationContext: Context
    private lateinit var downloadManager: NativeDownloadManager

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext

        // Room 数据库入口在插件 attach 时创建一次。
        // 后面所有下载任务共用同一个 Dao，不要每次下载都重复创建数据库。
        val database = DownloadDatabase.getInstance(applicationContext)
        downloadManager = NativeDownloadManager(database.downloadTaskDao())

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

                // deleteDownload 会访问 Room，不能在主线程直接执行。
                // 这里先用 Thread，后面学协程时再换成 CoroutineScope + Dispatchers.IO。
                Thread {
                    val accepted = downloadManager.deleteDownload(taskId)
                    mainHandler.post {
                        result.success(accepted)
                    }
                }.start()
            }

            "pauseDownload" -> {
                val taskId = call.argument<String>("taskId")
                if (taskId.isNullOrBlank()) {
                    result.error("missing_task_id", "pauseDownload requires a non-empty taskId", null)
                    return
                }

                Thread {
                    val accepted = downloadManager.pauseDownload(
                        taskId = taskId,
                        onProgress = ::sendDownloadEvent
                    )
                    mainHandler.post {
                        result.success(accepted)
                    }
                }.start()
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
