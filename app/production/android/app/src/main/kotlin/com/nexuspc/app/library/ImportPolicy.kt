package com.nexuspc.app.library

import java.io.File
import java.io.IOException
import java.text.Normalizer
import java.util.Locale

class ImportRejected(val code: String, message: String) : IOException(message)

data class ImportLimits(
    val maxEntries: Int = 20000,
    val maxBytes: Long = 8L * 1024 * 1024 * 1024,
    val maxFileBytes: Long = 2L * 1024 * 1024 * 1024,
    val maxArchiveBytes: Long = 4L * 1024 * 1024 * 1024,
    val maxExecutables: Int = 128,
    val maxDepth: Int = 32,
    val maxRatio: Long = 200,
    val reserveBytes: Long = 64L * 1024 * 1024,
)

/** Windows-compatible relative names. Neither provider labels nor ZIP names are paths we trust. */
object ImportPolicy {
    private val reserved = Regex("(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])")
    fun path(value: String, maxDepth: Int = 32): String {
        if (value.isEmpty() || value.length > 1024 || value.startsWith('/') ||
            value.contains('\\') || value.any { it in ":*?\"<>|" || it.code < 32 || it.code == 127 ||
                it in '\u202a'..'\u202e' || it in '\u2066'..'\u2069' }) rejectPath()
        val parts = value.split('/')
        if (parts.size > maxDepth || parts.any { it.isEmpty() || it == "." || it == ".." ||
                it.length > 255 || it.endsWith(' ') || it.endsWith('.') ||
                reserved.matches(it.substringBefore('.')) }) rejectPath()
        return value
    }
    fun child(root: File, relative: String): File {
        path(relative)
        val file = File(root, relative)
        if (!file.canonicalPath.startsWith(root.canonicalPath + File.separator)) rejectPath()
        return file
    }
    fun title(value: String): String {
        val trimmed = value.trim()
        if (trimmed.isEmpty() || trimmed.length > 120 || trimmed.any { it.code < 32 || it.code == 127 })
            throw ImportRejected("invalid_title", "Use a title of 1–120 characters without control characters.")
        return trimmed
    }
    fun id(value: String): String {
        if (!Regex("[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}").matches(value))
            throw ImportRejected("invalid_game", "Invalid game identifier.")
        return value
    }
    fun collisionKey(value: String): String = Normalizer.normalize(value, Normalizer.Form.NFC).lowercase(Locale.ROOT)
    private fun rejectPath(): Nothing = throw ImportRejected("unsafe_path", "An imported filename is unsafe or unsupported.")
}

/** Includes implicit ZIP directories: A/a.exe and a/b.dat must not alias a directory. */
class ImportNames(private val limits: ImportLimits) {
    private val names = mutableMapOf<String, Pair<String, Boolean>>()
    private val explicit = mutableSetOf<String>()
    private var count = 0
    fun add(relative: String, directory: Boolean) {
        ImportPolicy.path(relative, limits.maxDepth)
        if (++count > limits.maxEntries) throw ImportRejected("too_many_files", "Import contains too many entries.")
        if (!explicit.add(ImportPolicy.collisionKey(relative))) collision()
        val parts = relative.split('/')
        for (index in parts.indices) {
            val prefix = parts.take(index + 1).joinToString("/")
            val isDirectory = index < parts.lastIndex || directory
            val key = ImportPolicy.collisionKey(prefix)
            val existing = names[key]
            if (existing != null && (existing.first != prefix || existing.second != isDirectory)) collision()
            names[key] = prefix to isDirectory
        }
    }
    private fun collision(): Nothing = throw ImportRejected("name_collision", "Import contains duplicate or conflicting filenames.")
}
