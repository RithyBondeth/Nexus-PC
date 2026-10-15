package com.nexuspc.app.library

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.nexuspc.app.ExecutableRecord
import com.nexuspc.app.GameDetails
import com.nexuspc.app.GameRecord
import com.nexuspc.app.LibraryResult
import java.io.File
import java.nio.file.Files
import java.nio.file.SimpleFileVisitor
import java.nio.file.FileVisitResult
import java.nio.file.Path
import java.nio.file.attribute.BasicFileAttributes
import java.util.UUID

/** All calls belong to the library's one IO worker. Neither sources nor absolute paths enter this database. */
class LibraryStore(context: Context, rootOverride: File? = null) : AutoCloseable {
    val root = rootOverride ?: File(context.noBackupFilesDir.canonicalFile, "library-v1")
    private val staging = File(root, "staging")
    private val games = File(root, "games")
    private val owners = File(root, "owners")
    private val helper: SQLiteOpenHelper
    init {
        listOf(root, staging, games, owners).forEach {
            if (it.absolutePath != it.canonicalPath || (!it.isDirectory && !it.mkdirs()))
                throw ImportRejected("library_storage", "Library storage is unavailable.")
        }
        helper = object : SQLiteOpenHelper(context, File(root, "library.sqlite").absolutePath, null, 1) {
            override fun onCreate(db: SQLiteDatabase) {
                db.execSQL("CREATE TABLE games (id TEXT PRIMARY KEY, title TEXT NOT NULL, content_hash TEXT NOT NULL UNIQUE, bytes INTEGER NOT NULL, files INTEGER NOT NULL, imported INTEGER NOT NULL, selected TEXT, deleting INTEGER NOT NULL DEFAULT 0)")
                db.execSQL("CREATE TABLE executables (game_id TEXT NOT NULL REFERENCES games(id) ON DELETE CASCADE, path TEXT NOT NULL, architecture TEXT NOT NULL, hash TEXT NOT NULL, PRIMARY KEY(game_id,path))")
            }
            override fun onConfigure(db: SQLiteDatabase) { db.setForeignKeyConstraintsEnabled(true) }
            override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
                throw IllegalStateException("A library schema migration is required")
            }
        }
        try { recover() } catch (error: Exception) { helper.close(); throw error }
    }
    private val db: SQLiteDatabase get() = helper.writableDatabase
    fun createStage(id: String): File {
        val stage = File(staging, ImportPolicy.id(id))
        val marker = File(owners, id)
        if (!marker.createNewFile()) throw ImportRejected("library_storage", "Import identifier is already owned.")
        marker.outputStream().use { it.write(id.toByteArray(Charsets.US_ASCII)); it.fd.sync() }
        if (!stage.mkdir()) throw ImportRejected("library_storage", "Could not create an import workspace.")
        if (!File(stage, "content").mkdir()) throw ImportRejected("library_storage", "Could not create import content storage.")
        return stage
    }
    fun discardStage(id: String) {
        ImportPolicy.id(id)
        if (File(staging, id).exists()) removeOwned(staging, id)
        removeUnusedMarker(id)
    }
    fun publish(id: String, title: String, result: CopyResult): GameRecord {
        val validTitle = ImportPolicy.title(title)
        db.rawQuery("SELECT COUNT(*) FROM games", null).use {
            it.moveToFirst()
            if (it.getInt(0) >= 500) throw ImportRejected("library_full", "The local library is limited to 500 games.")
        }
        db.rawQuery("SELECT id FROM games WHERE content_hash = ?", arrayOf(result.contentHash)).use {
            if (it.moveToFirst()) throw ImportRejected("duplicate_game", "An identical copy is already in your library.")
        }
        val stage = owned(staging, id)
        val destination = File(games, ImportPolicy.id(id))
        val importedAt = System.currentTimeMillis()
        if (destination.exists() || !stage.renameTo(destination)) throw ImportRejected("library_storage", "Could not commit the imported copy.")
        try {
            db.beginTransaction()
            try {
                db.insertOrThrow("games", null, ContentValues().apply {
                    put("id", id); put("title", validTitle); put("content_hash", result.contentHash)
                    put("bytes", result.bytes); put("files", result.files); put("imported", importedAt)
                    if (result.executables.size == 1) put("selected", result.executables.single().relativePath)
                })
                for (exe in result.executables) db.insertOrThrow("executables", null, ContentValues().apply {
                    put("game_id", id); put("path", exe.relativePath); put("architecture", exe.architecture); put("hash", exe.sha256)
                })
                db.setTransactionSuccessful()
            } finally { db.endTransaction() }
        } catch (error: Exception) {
            removeOwned(games, id)
            removeUnusedMarker(id)
            throw error
        }
        val selected = result.executables.singleOrNull()
        return GameRecord(id, validTitle, result.contentHash, result.bytes, result.files, importedAt,
            result.executables.size.toLong(), selected?.relativePath, selected?.architecture, selected?.sha256)
    }
    fun list(offset: Long, limit: Long, query: String): LibraryResult {
        if (offset !in 0L..500L || limit !in 1L..50L || query.length > 120 || query.any { it.code < 32 })
            throw ImportRejected("invalid_argument", "Invalid library search or page.")
        val escaped = query.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        val args = arrayOf("%$escaped%")
        val where = "g.deleting=0 AND g.title LIKE ? ESCAPE '\\'"
        val total = db.rawQuery("SELECT COUNT(*) FROM games g WHERE $where", args).use { it.moveToFirst(); it.getLong(0) }
        val records = db.rawQuery("$recordSql WHERE $where ORDER BY g.imported DESC,g.id LIMIT ? OFFSET ?",
            args + arrayOf(limit.toString(), offset.toString())).use { cursor ->
            buildList { while (cursor.moveToNext()) add(record(cursor)) }
        }
        return LibraryResult(records, total)
    }
    fun details(id: String): GameDetails {
        ImportPolicy.id(id)
        val game = db.rawQuery("$recordSql WHERE g.id=? AND g.deleting=0", arrayOf(id)).use {
            if (!it.moveToFirst()) throw ImportRejected("game_missing", "This game is no longer in the library.")
            record(it)
        }
        val executables = db.rawQuery("SELECT path,architecture,hash FROM executables WHERE game_id=? ORDER BY path", arrayOf(id)).use { cursor ->
            buildList { while (cursor.moveToNext()) add(ExecutableRecord(cursor.getString(0), cursor.getString(1), cursor.getString(2))) }
        }
        return GameDetails(game, executables)
    }
    fun update(id: String, title: String, executable: String): GameRecord {
        val validTitle = ImportPolicy.title(title)
        ImportPolicy.path(executable)
        val entry = details(id).executables.firstOrNull { it.relativePath == executable }
            ?: throw ImportRejected("invalid_executable", "Choose an executable from this imported copy.")
        val verified = PeInspector.inspect(File(owned(games, id), "content"), executable)
        if (verified == null || verified.sha256 != entry.sha256)
            throw ImportRejected("executable_changed", "The imported executable is missing or has changed. Reimport the game.")
        db.update("games", ContentValues().apply { put("title", validTitle); put("selected", executable) }, "id=? AND deleting=0", arrayOf(id))
        return details(id).game
    }
    fun remove(id: String) {
        details(id) // Database ownership is required before touching a game copy.
        if (File(games, id).exists()) owned(games, id)
        db.update("games", ContentValues().apply { put("deleting", 1) }, "id=?", arrayOf(id))
        if (File(games, id).exists()) removeOwned(games, id)
        db.delete("games", "id=?", arrayOf(id))
        removeUnusedMarker(id)
    }
    private fun recover() {
        val records = db.rawQuery("SELECT id,deleting FROM games", null).use { cursor ->
            buildMap { while (cursor.moveToNext()) put(ImportPolicy.id(cursor.getString(0)), cursor.getInt(1) != 0) }
        }
        // Markers live outside removable leaves, so interrupted deletion retains ownership proof.
        staging.listFiles()?.forEach { removeOwned(staging, it.name) }
        games.listFiles()?.forEach {
            val deleting = records[it.name]
            if (deleting == null || deleting) {
                removeOwned(games, it.name)
                if (deleting == true) db.delete("games", "id=?", arrayOf(it.name))
            }
        }
        for ((id, deleting) in records) if (deleting && !File(games, id).exists()) db.delete("games", "id=?", arrayOf(id))
        owners.listFiles()?.forEach { removeUnusedMarker(ImportPolicy.id(it.name)) }
    }
    private fun owned(parent: File, id: String): File {
        val leaf = File(parent, ImportPolicy.id(id))
        val marker = File(owners, id)
        if (leaf.canonicalFile.parentFile != parent.canonicalFile || leaf.absolutePath != leaf.canonicalPath ||
            !leaf.isDirectory || marker.absolutePath != marker.canonicalPath || marker.length() != 36L ||
            marker.inputStream().use { input ->
                val bytes = ByteArray(36)
                java.io.DataInputStream(input).readFully(bytes)
                String(bytes, Charsets.US_ASCII) != id || input.read() != -1
            })
            throw ImportRejected("library_storage", "Library copy ownership could not be verified.")
        return leaf
    }
    private fun removeOwned(parent: File, id: String) {
        val leaf = owned(parent, id)
        Files.walkFileTree(leaf.toPath(), object : SimpleFileVisitor<Path>() {
            override fun visitFile(file: Path, attrs: BasicFileAttributes): FileVisitResult {
                Files.delete(file); return FileVisitResult.CONTINUE
            }
            override fun postVisitDirectory(dir: Path, error: java.io.IOException?): FileVisitResult {
                if (error != null) throw error
                Files.delete(dir); return FileVisitResult.CONTINUE
            }
        })
    }
    private fun removeUnusedMarker(id: String) {
        // This removes only a generated metadata file, never an unverified directory tree.
        if (!File(staging, id).exists() && !File(games, id).exists()) {
            val marker = File(owners, id)
            if (marker.exists()) {
                if (marker.absolutePath != marker.canonicalPath || !marker.isFile || marker.length() > 36)
                    throw ImportRejected("library_storage", "Library ownership metadata is invalid.")
                Files.delete(marker.toPath())
            }
        }
    }
    private fun record(cursor: Cursor) = GameRecord(cursor.getString(0), cursor.getString(1), cursor.getString(2),
        cursor.getLong(3), cursor.getLong(4), cursor.getLong(5), cursor.getLong(6),
        cursor.getString(7), cursor.getString(8), cursor.getString(9))
    override fun close() { helper.close() }
    companion object {
        fun newId(): String = UUID.randomUUID().toString()
        private const val recordSql = "SELECT g.id,g.title,g.content_hash,g.bytes,g.files,g.imported,(SELECT COUNT(*) FROM executables x WHERE x.game_id=g.id),g.selected,e.architecture,e.hash FROM games g LEFT JOIN executables e ON e.game_id=g.id AND e.path=g.selected"
    }
}
