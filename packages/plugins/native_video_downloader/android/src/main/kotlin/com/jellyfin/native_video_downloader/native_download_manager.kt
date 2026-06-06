package com.jellyfin.native_video_downloader

/**
 * Android 原生下载管理器。
 *
 * 现在先不做真实下载，只负责创建一个模拟 taskId。
 * 后面真实的协程、OkHttp、暂停恢复、多任务管理都会逐步放到这里。
 */
class NativeDownloadManager {
    fun startDownload(): String {
        return "task_${System.currentTimeMillis()}"
    }
}
