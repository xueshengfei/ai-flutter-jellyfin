package com.jellyfin.native_video_downloader

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

/**
 * Room 数据库入口。
 *
 * Database 可以理解成“数据库总开关”：
 * - entities 告诉 Room 这个数据库里有哪些表。
 * - version 是数据库版本号，后面改表结构时要升级它。
 * - abstract fun downloadTaskDao() 暴露 Dao，让业务代码能读写表。
 */
@Database(
    entities = [DownloadTaskEntity::class],
    version = 1,
    exportSchema = false
)
abstract class DownloadDatabase : RoomDatabase() {
    abstract fun downloadTaskDao(): DownloadTaskDao

    companion object {
        /**
         * volatile 保证多线程读取 instance 时能看到最新值。
         *
         * RoomDatabase 通常全 app 只建一个实例，不要每次下载都 new 一个。
         */
        @Volatile
        private var instance: DownloadDatabase? = null

        fun getInstance(context: Context): DownloadDatabase {
            return instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    DownloadDatabase::class.java,
                    "native_video_downloader.db"
                ).build().also { database ->
                    instance = database
                }
            }
        }
    }
}
