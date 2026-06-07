package com.jellyfin.native_video_downloader

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query

/**
 * 下载任务表的操作入口。
 *
 * Dao 可以理解成“数据库操作方法集合”：
 * - Entity 负责定义表长什么样。
 * - Dao 负责定义怎么查、怎么写、怎么删。
 *
 * 这里先不用 suspend，是因为当前下载代码本来就在后台 Thread 里运行。
 * Room 不允许在主线程读写数据库；后面我们改协程时，再把这些方法升级成 suspend。
 */
@Dao
interface DownloadTaskDao {
    /**
     * 插入或覆盖一条下载任务。
     *
     * OnConflictStrategy.REPLACE 的意思是：
     * 如果 taskId 已经存在，就用新记录替换旧记录。
     */
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun upsert(task: DownloadTaskEntity)

    /**
     * 按 taskId 查询单条任务。
     */
    @Query("SELECT * FROM download_tasks WHERE taskId = :taskId LIMIT 1")
    fun findByTaskId(taskId: String): DownloadTaskEntity?

    /**
     * 按 url 查询已经完成的缓存记录。
     *
     * 下一步做“不重复下载”时，会先调用这个方法：
     * 如果查到了 completed 记录，并且 filePath 对应文件还存在，就不用重复下载。
     */
    @Query("SELECT * FROM download_tasks WHERE url = :url AND state = 'completed' LIMIT 1")
    fun findCompletedByUrl(url: String): DownloadTaskEntity?

    /**
     * 删除一条任务记录。
     *
     * 返回值是删除的行数：
     * - 0 表示没有找到这条记录。
     * - 1 表示成功删除一条记录。
     */
    @Query("DELETE FROM download_tasks WHERE taskId = :taskId")
    fun deleteByTaskId(taskId: String): Int
}
