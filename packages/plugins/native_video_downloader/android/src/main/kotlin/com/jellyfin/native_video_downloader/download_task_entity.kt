package com.jellyfin.native_video_downloader

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * Room 里的下载任务表。
 *
 * 你可以把 Entity 理解成“数据库表结构的 Kotlin 写法”：
 * - @Entity 表示这是 Room 的一张表。
 * - tableName 是真实表名。
 * - @PrimaryKey 表示主键，Room 用它区分每一条记录。
 *
 * 注意：数据库只存“视频文件在哪里、下载到什么状态”这些元数据。
 * 真正的视频字节还是保存在 app 的文件目录里，不会塞进数据库。
 */
@Entity(
    tableName = "download_tasks",
    indices = [
        // 后面做“不重复下载”时，会经常按 url 查已缓存记录，所以先给 url 建索引。
        Index(value = ["url"])
    ]
)
data class DownloadTaskEntity(
    /**
     * 当前下载任务 ID。
     *
     * 现在 taskId 由 NativeDownloadManager 生成，例如 task_1710000000000。
     * 后面接 Jellyfin 时，可以考虑改成 jellyfinItemId 或 url hash。
     */
    @PrimaryKey
    val taskId: String,

    /**
     * 原始下载地址。
     *
     * 后面判断“这个视频是否已经下载过”，最简单的第一版就是按 url 查。
     */
    val url: String,

    /**
     * 下载完成后的本地文件路径。
     *
     * 下载中或失败时可能还没有可用文件，所以这里允许为 null。
     */
    val filePath: String?,

    /**
     * 服务端返回的总字节数。
     *
     * 如果服务端没有稳定 Content-Length，这里可能是 -1 或 0。
     */
    val totalBytes: Long,

    /**
     * 已下载字节数。
     */
    val downloadedBytes: Long,

    /**
     * 任务状态。
     *
     * 先用 String 是为了学习阶段直观：
     * downloading / completed / failed / deleted。
     * 后面稳定后可以再封装成 enum 映射。
     */
    val state: String,

    /**
     * 创建时间，毫秒时间戳。
     */
    val createdAtMillis: Long,

    /**
     * 最后更新时间，毫秒时间戳。
     */
    val updatedAtMillis: Long
)
