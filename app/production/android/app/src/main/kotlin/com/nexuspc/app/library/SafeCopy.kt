package com.nexuspc.app.library

import java.io.Closeable
import java.io.File
import java.io.InputStream
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicBoolean
import java.util.zip.CRC32
import java.util.zip.ZipFile

class CopyControl(val limits: ImportLimits = ImportLimits()) {
    private val cancelled = AtomicBoolean(false)
    private val deadline = System.nanoTime() + 15L * 60 * 1_000_000_000
    @Volatile var bytes: Long = 0; private set
    @Volatile var files: Long = 0; private set
    @Volatile private var active: Closeable? = null
    fun cancel() {
        if (cancelled.compareAndSet(false, true)) {
            // A provider stream may block in read; never close it on the Android UI thread.
            Thread({ try { active?.close() } catch (_: Exception) {} }, "nexus-import-cancel").start()
        }
    }
    fun checkpoint() {
        if (cancelled.get() || Thread.currentThread().isInterrupted)
            throw ImportRejected("cancelled", "Import cancelled. No game was added.")
        if (System.nanoTime() > deadline) throw ImportRejected("import_timeout", "Import took too long. Try a local source.")
    }
    fun <T> reading(input: InputStream, operation: () -> T): T {
        active = input
        try { checkpoint(); return operation() } finally { active = null; input.close() }
    }
    fun copied(count: Int) {
        bytes += count
        if (bytes > limits.maxBytes) throw ImportRejected("import_too_large", "Import exceeds the 8 GiB expanded-data limit.")
    }
    fun fileFinished() { files++ }
}

data class CopiedFile(val relative: String, val bytes: Long, val hash: String)
data class CopyResult(val bytes: Long, val files: Long, val contentHash: String, val executables: List<PeExecutable>)

/** Writes only beneath a newly created private content directory, and never creates links. */
class SafeCopy(private val content: File, val control: CopyControl) {
    private val names = ImportNames(control.limits)
    private val copied = mutableListOf<CopiedFile>()
    init {
        require(content.isDirectory && content.list()?.isEmpty() == true)
    }
    fun directory(relative: String) {
        control.checkpoint()
        names.add(relative, true)
        val destination = ImportPolicy.child(content, relative)
        if (!destination.isDirectory && !destination.mkdirs()) throw java.io.IOException("Cannot create directory")
    }
    fun file(relative: String, input: InputStream, expectedBytes: Long? = null, expectedCrc: Long? = null) {
        input.use {
            control.checkpoint()
            names.add(relative, false)
            if (expectedBytes != null && expectedBytes !in 0..control.limits.maxFileBytes)
                throw ImportRejected("file_too_large", "An imported file exceeds the 2 GiB limit.")
            val destination = ImportPolicy.child(content, relative)
            if (!destination.parentFile!!.isDirectory && !destination.parentFile!!.mkdirs()) throw java.io.IOException("Cannot create parent")
            if (!destination.createNewFile()) throw ImportRejected("name_collision", "Import would overwrite a file.")
            val (size, hash, crc) = copy(it, destination, control.limits.maxFileBytes, countExpanded = true)
            if ((expectedBytes != null && expectedBytes != size) || (expectedCrc != null && expectedCrc != crc))
                throw ImportRejected("invalid_archive", "Archive data is incomplete or corrupt.")
            copied.add(CopiedFile(relative, size, hash))
            control.fileFinished()
        }
    }
    fun archive(input: InputStream, archiveFile: File) {
        // Spool with a compressed-byte limit so ZipFile can validate the central directory.
        copy(input, archiveFile, control.limits.maxArchiveBytes, countExpanded = false)
        val expectedEntries = ZipPreflight.validate(archiveFile, control.limits)
        ZipFile(archiveFile).use { zip ->
            if (zip.size() != expectedEntries) throw ImportRejected("invalid_archive", "ZIP metadata is inconsistent.")
            val entries = zip.entries()
            while (entries.hasMoreElements()) {
                control.checkpoint()
                val entry = entries.nextElement()
                val name = if (entry.isDirectory) entry.name.removeSuffix("/") else entry.name
                if (entry.method !in listOf(0, 8) || entry.size < 0 || entry.compressedSize < 0 || entry.crc < 0)
                    throw ImportRejected("invalid_archive", "ZIP format is unsupported or corrupt.")
                if (entry.size > 0 && (entry.compressedSize == 0L || entry.size > entry.compressedSize * control.limits.maxRatio))
                    throw ImportRejected("archive_ratio", "Archive compression ratio exceeds the safe-import limit.")
                if (entry.isDirectory) {
                    if (entry.size != 0L) throw ImportRejected("invalid_archive", "Archive directory contains unexpected data.")
                    directory(name)
                } else file(name, zip.getInputStream(entry), entry.size, entry.crc)
            }
        }
    }
    private fun copy(input: InputStream, destination: File, limit: Long, countExpanded: Boolean): Triple<Long, String, Long> {
        val hash = MessageDigest.getInstance("SHA-256")
        val crc = CRC32()
        var size = 0L
        var nextSpaceCheck = 0L
        control.reading(input) {
            destination.outputStream().use { output ->
                val buffer = ByteArray(128 * 1024)
                while (true) {
                    control.checkpoint()
                    val count = input.read(buffer)
                    if (count < 0) break
                    if (count == 0) continue
                    size += count
                    if (size > limit) throw ImportRejected("file_too_large", "Selected data exceeds the safe-import size limit.")
                    if (countExpanded) control.copied(count)
                    if (size >= nextSpaceCheck) {
                        if (destination.parentFile!!.usableSpace < control.limits.reserveBytes + count)
                            throw ImportRejected("insufficient_space", "Not enough free storage to import safely.")
                        nextSpaceCheck = size + 1024 * 1024
                    }
                    output.write(buffer, 0, count)
                    hash.update(buffer, 0, count)
                    crc.update(buffer, 0, count)
                }
                output.fd.sync()
            }
        }
        return Triple(size, hash.digest().joinToString("") { "%02x".format(it) }, crc.value)
    }
    fun finish(): CopyResult {
        val candidates = mutableListOf<PeExecutable>()
        val contentHash = MessageDigest.getInstance("SHA-256")
        for (file in copied.sortedBy { it.relative }) {
            control.checkpoint()
            contentHash.update((file.relative + '\u0000' + file.hash + '\u0000').toByteArray(Charsets.UTF_8))
            PeInspector.inspect(content, file.relative, control::checkpoint)?.let {
                if (candidates.size >= control.limits.maxExecutables)
                    throw ImportRejected("too_many_executables", "Import contains too many Windows executables.")
                candidates.add(it)
            }
        }
        if (candidates.isEmpty()) throw ImportRejected("no_executable", "No supported x86 or x86-64 Windows PE executable was found.")
        return CopyResult(control.bytes, control.files, contentHash.digest().joinToString("") { "%02x".format(it) }, candidates)
    }
}
