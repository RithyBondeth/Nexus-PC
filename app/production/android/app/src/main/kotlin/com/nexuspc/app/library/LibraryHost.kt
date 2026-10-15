package com.nexuspc.app.library

import android.app.Activity
import android.content.Intent
import com.nexuspc.app.*
import java.util.concurrent.atomic.AtomicInteger

/** Activity-scoped picker routing; IO and import state belong to the process manager. */
class LibraryHost(private val activity: Activity) : NexusLibraryApi {
    private val manager = LibraryManager.get(activity.applicationContext)
    private var pending: Triple<Int, String, ImportKind>? = null
    private var closed = false
    override fun listGames(offset: Long, limit: Long, query: String, callback: (Result<LibraryResult>) -> Unit) =
        manager.access({ if (!closed) callback(it) }) { it.list(offset, limit, query) }
    override fun getGame(gameId: String, callback: (Result<GameDetails>) -> Unit) =
        manager.access({ if (!closed) callback(it) }) { it.details(gameId) }
    override fun updateGame(gameId: String, title: String, executableRelativePath: String, callback: (Result<GameRecord>) -> Unit) =
        manager.access({ if (!closed) callback(it) }) { it.update(gameId, title, executableRelativePath) }
    override fun removeGame(gameId: String, callback: (Result<Unit>) -> Unit) =
        manager.access({ if (!closed) callback(it) }) { it.remove(gameId) }
    override fun getImportProgress(): ImportProgress = manager.progress()
    override fun cancelImport(jobId: String) { manager.cancel(jobId) }
    @Suppress("DEPRECATION")
    override fun beginImport(kind: ImportKind): ImportProgress {
        val request = requests.incrementAndGet()
        if (request > 65000) throw FlutterError("picker_unavailable", "Restart Nexus-PC before another import.")
        val progress = manager.begin()
        val id = progress.jobId!!
        pending = Triple(request, id, kind)
        try {
            val intent = if (kind == ImportKind.FOLDER) Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                else Intent(Intent.ACTION_GET_CONTENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE); type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/zip", "application/x-zip-compressed", "application/octet-stream"))
                }
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            activity.startActivityForResult(intent, request)
        } catch (_: Exception) { pending = null; manager.pickerFailed(id) }
        return manager.progress()
    }
    fun onActivityResult(request: Int, result: Int, data: Intent?): Boolean {
        val selection = pending ?: return false
        if (selection.first != request) return false
        pending = null
        val uri = data?.data
        if (result == Activity.RESULT_OK && uri != null) manager.selected(selection.second, uri, selection.third)
        else manager.pickerCancelled(selection.second)
        return true
    }
    fun close() {
        closed = true
        pending?.let { manager.pickerCancelled(it.second) }
        pending = null
    }
    companion object { private val requests = AtomicInteger(18000) }
}
