package com.jellyfin.native_video_downloader

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import java.util.Timer
import java.util.TimerTask
/**
 * native_video_downloader 的 Android 插件入口。
 *
 * 你可以把这个类理解成 Flutter 和 Android 原生之间的“接待台”：
 *
 * Flutter 侧调用 MethodChannel.invokeMethod(...)
 *   -> 消息经过 Flutter Engine 的 binaryMessenger
 *   -> 到达这个 Kotlin 类的 onMethodCall(...)
 *   -> Android 根据 method 名字执行对应逻辑
 *   -> 通过 result.success / result.error / result.notImplemented 返回给 Flutter
 *
 * 现在这个文件还只是 flutter create 生成的最小模板。
 * 后面我们会先在这里加 startDownload，再把真正下载逻辑拆到 DownloadManager。
 */
class NativeVideoDownloaderPlugin :
    FlutterPlugin,
    MethodCallHandler {
    /**
     * MethodChannel 是 Flutter 调 Android 的通道。
     *
     * Dart 侧必须使用同一个 channel 名字：
     *   MethodChannel("native_video_downloader")
     *
     * 现在这个 channel 只处理“一问一答”的命令，例如：
     *   - getPlatformVersion
     *   - startDownload
     *   - pauseDownload
     *   - resumeDownload
     *
     * 实时下载进度不适合放在 MethodChannel 里反复回调。
     * 后面我们会单独加 EventChannel 来推送 progress / speed / state。
     */
    private lateinit var channel: MethodChannel

    private val downloadManager = NativeDownloadManager()

    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var progressTimer: Timer? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    /**
     * Flutter Engine 绑定插件时会调用这里。
     *
     * 你可以把它理解成“插件启动”：
     *   1. 创建 MethodChannel
     *   2. 把当前类注册成 MethodCallHandler
     *
     * 注册完成后，Flutter 侧 invokeMethod(...) 才能进入 onMethodCall(...)。
     */
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "native_video_downloader")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "native_video_downloader/events"
        )

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                progressTimer?.cancel()
                progressTimer = null
            }
        })
    }

    /**
     * Flutter 侧每调用一次 invokeMethod，Android 侧就会进入这里一次。
     *
     * call.method 是方法名，例如 "getPlatformVersion"。
     * call.arguments 是 Dart 传来的参数，例如 Map、String、Int 等。
     * result 是返回通道，必须调用一次：
     *   - result.success(value)：正常返回
     *   - result.error(code, message, details)：失败返回
     *   - result.notImplemented()：这个方法 Android 不认识
     *
     * 后面你写 startDownload 时，第一步就是在这里加一个分支：
     *   if (call.method == "startDownload") { ... }
     */
    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }

            "startDownload" -> {
                val taskId = downloadManager.startDownload()
                startMockProgress(taskId)
                result.success(taskId)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Flutter Engine 解绑插件时会调用这里。
     *
     * 你可以把它理解成“插件关闭”：
     *   - 清掉 MethodCallHandler，避免 Engine 销毁后还持有旧引用。
     *
     * 后面如果我们在插件里创建协程、下载任务、EventChannel，
     * 也要在这里考虑释放资源。
     */
    /**
     * 启动一个模拟下载进度。
     *
     * 现在这里还不做真实网络下载，只用 Timer 每秒推一次假数据。
     * Flutter 侧通过 EventChannel 监听这些事件，就能看到进度实时变化。
     */
    private fun startMockProgress(taskId: String) {
        progressTimer?.cancel()

        var progress = 0
        progressTimer = Timer()

        progressTimer?.scheduleAtFixedRate(
            object : TimerTask() {
                override fun run() {
                    progress += 10

                    val event = mapOf(
                        "taskId" to taskId,
                        "progress" to progress,
                        "speedBytesPerSecond" to 1024 * 1024 * 3,
                        "state" to if (progress >= 100) "completed" else "downloading"
                    )

                    mainHandler.post {
                        eventSink?.success(event)
                    }

                    if (progress >= 100) {
                        progressTimer?.cancel()
                        progressTimer = null
                    }
                }
            },
            0,
            1000
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        progressTimer?.cancel()
        progressTimer = null
        eventSink = null
        eventChannel.setStreamHandler(null)
        channel.setMethodCallHandler(null)
    }
}
