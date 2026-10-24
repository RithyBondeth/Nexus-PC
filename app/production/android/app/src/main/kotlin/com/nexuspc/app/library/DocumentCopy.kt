package com.nexuspc.app.library

import android.content.Context
import android.net.Uri
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import com.nexuspc.app.ImportKind
import java.io.File

/** Reads only picker-granted content URIs. Never resolves a provider's display name into a source path. */
class DocumentCopy(private val context: Context, private val signal: CancellationSignal) {
    private val resolver = context.contentResolver
    fun copy(uri: Uri, kind: ImportKind, copier: SafeCopy, archive: File): String {
        if (uri.scheme != "content" || uri.authority.isNullOrEmpty() || uri.toString().length > 4096)
            throw ImportRejected("invalid_source", "Select a source using the system file picker.")
        if (kind == ImportKind.ZIP) {
            val name = resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null, signal)?.use {
                if (it.moveToFirst()) it.getString(0) else null
            } ?: "Imported game"
            copier.archive(open(uri), archive)
            return title(name.removeSuffix(".zip").removeSuffix(".ZIP"))
        }
        if (!DocumentsContract.isTreeUri(uri)) throw ImportRejected("invalid_source", "Select a game folder.")
        val rootId = DocumentsContract.getTreeDocumentId(uri)
        val rootUri = DocumentsContract.buildDocumentUriUsingTree(uri, rootId)
        val rootName = resolver.query(rootUri, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE), null, null, null, signal)?.use {
            if (!it.moveToFirst() || it.getString(1) != DocumentsContract.Document.MIME_TYPE_DIR)
                throw ImportRejected("invalid_source", "Select a game folder.")
            it.getString(0)
        } ?: throw ImportRejected("source_unavailable", "The selected folder could not be read.")
        val visited = mutableSetOf(rootId)
        fun visit(parentId: String, prefix: String, depth: Int) {
            copier.control.checkpoint()
            if (depth > copier.control.limits.maxDepth) throw ImportRejected("unsafe_path", "Source folders are nested too deeply.")
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(uri, parentId)
            val projection = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID, DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE, DocumentsContract.Document.COLUMN_SIZE, DocumentsContract.Document.COLUMN_FLAGS)
            val cursor = resolver.query(children, projection, null, null, null, signal)
                ?: throw ImportRejected("source_unavailable", "The selected folder could not be read.")
            cursor.use {
                while (it.moveToNext()) {
                    copier.control.checkpoint()
                    val id = it.getString(0) ?: throw ImportRejected("invalid_source", "The provider returned an invalid document.")
                    val name = it.getString(1) ?: throw ImportRejected("invalid_source", "The provider returned an unnamed document.")
                    // A child label must be a single component, not an injected subdirectory path.
                    ImportPolicy.path(name, 1)
                    if (id.length > 2048 || !visited.add(id)) throw ImportRejected("source_cycle", "The source contains repeated or cyclic documents.")
                    if (visited.size > copier.control.limits.maxEntries + 1) throw ImportRejected("too_many_files", "Source contains too many entries.")
                    if (it.getInt(4) and DocumentsContract.Document.FLAG_VIRTUAL_DOCUMENT != 0)
                        throw ImportRejected("unsupported_source", "Virtual documents are not supported. Choose local files.")
                    val relative = if (prefix.isEmpty()) name else "$prefix/$name"
                    if (it.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) {
                        copier.directory(relative)
                        visit(id, relative, depth + 1)
                    } else {
                        val document = DocumentsContract.buildDocumentUriUsingTree(uri, id)
                        copier.file(relative, open(document), if (it.isNull(3)) null else it.getLong(3))
                    }
                }
            }
        }
        visit(rootId, "", 1)
        return title(rootName)
    }
    private fun open(uri: Uri) = ParcelFileDescriptor.AutoCloseInputStream(
        resolver.openFileDescriptor(uri, "r", signal)
            ?: throw ImportRejected("source_unavailable", "The selected data could not be opened."))
    private fun title(value: String): String = ImportPolicy.title(
        value.filterNot { it.code < 32 || it.code == 127 || it in '\u202a'..'\u202e' || it in '\u2066'..'\u2069' }
            .trim().take(120).ifBlank { "Imported game" })
}
