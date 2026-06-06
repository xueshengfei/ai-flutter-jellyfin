package com.jellyfin.native_video_downloader

import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import okhttp3.OkHttpClient
import okhttp3.Request

/**
 * Android 原生下载管理器。
 *
 * 当前阶段只做最小真实下载：
 * - 用 OkHttp 发起 GET 请求。
 * - 从 ResponseBody 的 byteStream 读取 MP4 字节。
 * - 写入 app cache 目录。
 * - 通过 onProgress 回调把真实进度交给插件入口。
 *
 * 后面再逐步加协程、暂停、恢复、数据库和 Range 多线程。
 */
class NativeDownloadManager {
    private val client = OkHttpClient()

    fun startDownload(
        url: String,
        cacheDir: File,
        onProgress: (Map<String, Any>) -> Unit
    ): String {
        val taskId = "task_${System.currentTimeMillis()}"

        Thread {
            downloadOnBackgroundThread(
                taskId = taskId,
                url = url,
                cacheDir = cacheDir,
                onProgress = onProgress
            )
        }.start()

        return taskId
    }

    private fun downloadOnBackgroundThread(
        taskId: String,
        url: String,
        cacheDir: File,
        onProgress: (Map<String, Any>) -> Unit
    ) {
        val outputFile = File(cacheDir, "$taskId.mp4")

        try {
            onProgress(
                mapOf(
                    "taskId" to taskId,
                    "progress" to 0,
                    "downloadedBytes" to 0L,
                    "totalBytes" to 0L,
                    "speedBytesPerSecond" to 0L,
                    "state" to "downloading"
                )
            )

            val request = Request.Builder()
                .url(url)
                .build()

            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    throw IOException("Unexpected HTTP ${response.code}")
                }

                val body = response.body ?: throw IOException("Empty response body")
                val totalBytes = body.contentLength()
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                var downloadedBytes = 0L
                var lastReportBytes = 0L
                var lastReportAt = System.currentTimeMillis()

                body.byteStream().use { input ->
                    FileOutputStream(outputFile).use { output ->
                        while (true) {
                            val read = input.read(buffer)
                            if (read == -1) break

                            output.write(buffer, 0, read)
                            downloadedBytes += read

                            val now = System.currentTimeMillis()
                            if (now - lastReportAt >= REPORT_INTERVAL_MS) {
                                val speed = calculateSpeedBytesPerSecond(
                                    downloadedBytes = downloadedBytes,
                                    lastReportBytes = lastReportBytes,
                                    now = now,
                                    lastReportAt = lastReportAt
                                )

                                onProgress(
                                    mapOf(
                                        "taskId" to taskId,
                                        "progress" to calculateProgress(downloadedBytes, totalBytes),
                                        "downloadedBytes" to downloadedBytes,
                                        "totalBytes" to totalBytes,
                                        "speedBytesPerSecond" to speed,
                                        "state" to "downloading"
                                    )
                                )

                                lastReportBytes = downloadedBytes
                                lastReportAt = now
                            }
                        }
                    }
                }

                onProgress(
                    mapOf(
                        "taskId" to taskId,
                        "progress" to 100,
                        "downloadedBytes" to downloadedBytes,
                        "totalBytes" to totalBytes,
                        "speedBytesPerSecond" to 0L,
                        "state" to "completed",
                        "filePath" to outputFile.absolutePath
                    )
                )
            }
        } catch (error: Exception) {
            onProgress(
                mapOf(
                    "taskId" to taskId,
                    "progress" to 0,
                    "downloadedBytes" to 0L,
                    "totalBytes" to 0L,
                    "speedBytesPerSecond" to 0L,
                    "state" to "failed",
                    "errorMessage" to (error.message ?: error::class.java.simpleName)
                )
            )
        }
    }

    private fun calculateProgress(
        downloadedBytes: Long,
        totalBytes: Long
    ): Int {
        if (totalBytes <= 0L) return 0
        return ((downloadedBytes * 100) / totalBytes).toInt().coerceIn(0, 100)
    }

    private fun calculateSpeedBytesPerSecond(
        downloadedBytes: Long,
        lastReportBytes: Long,
        now: Long,
        lastReportAt: Long
    ): Long {
        val elapsedMs = now - lastReportAt
        if (elapsedMs <= 0L) return 0L
        return ((downloadedBytes - lastReportBytes) * 1000L) / elapsedMs
    }

    private companion object {
        const val DEFAULT_BUFFER_SIZE = 8 * 1024
        const val REPORT_INTERVAL_MS = 500L
    }
}
