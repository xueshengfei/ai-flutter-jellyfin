package com.jellyfin.native_video_downloader

import android.util.Log
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import okhttp3.Call
import okhttp3.OkHttpClient
import okhttp3.Request

/**
 * Android 原生下载管理器。
 *
 * 这个类不直接认识 Flutter，也不直接操作 MethodChannel。
 * 它只专心做“原生下载业务”：OkHttp 下载、Room 状态保存、进度事件回调。
 */
class NativeDownloadManager(
    private val downloadTaskDao: DownloadTaskDao
) {
    private val client = OkHttpClient()

    /**
     * 正在下载的 OkHttp Call。
     *
     * taskId -> Call。暂停时通过 taskId 找到 Call，然后 cancel。
     */
    private val activeCalls = ConcurrentHashMap<String, Call>()

    /**
     * 记录哪些任务是“用户主动暂停”。
     *
     * OkHttp Call 被 cancel 后也会抛异常；这里用这个集合区分：
     * - 用户暂停导致的异常 -> paused
     * - 网络/HTTP 失败导致的异常 -> failed
     */
    private val pausedTaskIds = ConcurrentHashMap.newKeySet<String>()

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

    /**
     * 暂停下载。
     *
     * 当前阶段的“暂停”本质是取消正在进行的 OkHttp Call。
     * 后面做断点续传时，会继续记录已下载字节和 Range 起点，再实现 resume。
     */
    fun pauseDownload(
        taskId: String,
        onProgress: (Map<String, Any>) -> Unit
    ): Boolean {
        val call = activeCalls[taskId] ?: return false
        pausedTaskIds.add(taskId)
        call.cancel()
        Log.d(TAG, "pauseDownload requested: $taskId")
        return true
    }

    /**
     * 接收 Flutter 发来的删除下载任务信号。
     *
     * 当前阶段只删除 Room 记录，不删除本地视频文件。
     */
    fun deleteDownload(taskId: String): Boolean {
        val deletedRows = downloadTaskDao.deleteByTaskId(taskId)
        Log.d(TAG, "deleteDownload requested: $taskId, deletedRows=$deletedRows")
        return true
    }

    private fun downloadOnBackgroundThread(
        taskId: String,
        url: String,
        cacheDir: File,
        onProgress: (Map<String, Any>) -> Unit
    ) {
        val outputFile = File(cacheDir, "$taskId.mp4")
        var totalBytes = 0L
        var downloadedBytes = 0L

        try {
            saveTaskState(
                taskId = taskId,
                url = url,
                filePath = null,
                totalBytes = 0L,
                downloadedBytes = 0L,
                state = STATE_DOWNLOADING
            )

            onProgress(
                mapOf(
                    "taskId" to taskId,
                    "progress" to 0,
                    "downloadedBytes" to 0L,
                    "totalBytes" to 0L,
                    "speedBytesPerSecond" to 0L,
                    "state" to STATE_DOWNLOADING
                )
            )

            val request = Request.Builder()
                .url(url)
                .build()
            val call = client.newCall(request)
            activeCalls[taskId] = call

            call.execute().use { response ->
                if (!response.isSuccessful) {
                    throw IOException("Unexpected HTTP ${response.code}")
                }

                val body = response.body ?: throw IOException("Empty response body")
                totalBytes = body.contentLength()
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
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
                                        "state" to STATE_DOWNLOADING
                                    )
                                )

                                lastReportBytes = downloadedBytes
                                lastReportAt = now
                            }
                        }
                    }
                }

                saveTaskState(
                    taskId = taskId,
                    url = url,
                    filePath = outputFile.absolutePath,
                    totalBytes = totalBytes,
                    downloadedBytes = downloadedBytes,
                    state = STATE_COMPLETED
                )

                onProgress(
                    mapOf(
                        "taskId" to taskId,
                        "progress" to 100,
                        "downloadedBytes" to downloadedBytes,
                        "totalBytes" to totalBytes,
                        "speedBytesPerSecond" to 0L,
                        "state" to STATE_COMPLETED,
                        "filePath" to outputFile.absolutePath
                    )
                )
            }
        } catch (error: Exception) {
            if (pausedTaskIds.remove(taskId)) {
                saveTaskState(
                    taskId = taskId,
                    url = url,
                    filePath = if (outputFile.exists()) outputFile.absolutePath else null,
                    totalBytes = totalBytes,
                    downloadedBytes = downloadedBytes,
                    state = STATE_PAUSED
                )

                onProgress(
                    mapOf(
                        "taskId" to taskId,
                        "progress" to calculateProgress(downloadedBytes, totalBytes),
                        "downloadedBytes" to downloadedBytes,
                        "totalBytes" to totalBytes,
                        "speedBytesPerSecond" to 0L,
                        "state" to STATE_PAUSED
                    )
                )
                return
            }

            saveTaskState(
                taskId = taskId,
                url = url,
                filePath = null,
                totalBytes = totalBytes,
                downloadedBytes = downloadedBytes,
                state = STATE_FAILED
            )

            onProgress(
                mapOf(
                    "taskId" to taskId,
                    "progress" to calculateProgress(downloadedBytes, totalBytes),
                    "downloadedBytes" to downloadedBytes,
                    "totalBytes" to totalBytes,
                    "speedBytesPerSecond" to 0L,
                    "state" to STATE_FAILED,
                    "errorMessage" to (error.message ?: error::class.java.simpleName)
                )
            )
        } finally {
            activeCalls.remove(taskId)
        }
    }

    private fun saveTaskState(
        taskId: String,
        url: String,
        filePath: String?,
        totalBytes: Long,
        downloadedBytes: Long,
        state: String
    ) {
        val now = System.currentTimeMillis()
        val oldTask = downloadTaskDao.findByTaskId(taskId)

        downloadTaskDao.upsert(
            DownloadTaskEntity(
                taskId = taskId,
                url = url,
                filePath = filePath,
                totalBytes = totalBytes,
                downloadedBytes = downloadedBytes,
                state = state,
                createdAtMillis = oldTask?.createdAtMillis ?: now,
                updatedAtMillis = now
            )
        )
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
        const val TAG = "NativeDownloadManager"
        const val DEFAULT_BUFFER_SIZE = 8 * 1024
        const val REPORT_INTERVAL_MS = 500L

        const val STATE_DOWNLOADING = "downloading"
        const val STATE_PAUSED = "paused"
        const val STATE_COMPLETED = "completed"
        const val STATE_FAILED = "failed"
    }
}
