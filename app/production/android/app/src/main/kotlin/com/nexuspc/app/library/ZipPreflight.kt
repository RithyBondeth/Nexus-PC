package com.nexuspc.app.library

import java.io.File
import java.io.RandomAccessFile

/** Bounds parser metadata before ZipFile allocation; this phase deliberately supports single-disk ZIP32 only. */
object ZipPreflight {
    fun validate(file: File, limits: ImportLimits): Int = RandomAccessFile(file, "r").use { reader ->
        val length = reader.length()
        if (length < 22 || length > limits.maxArchiveBytes) invalid()
        val tailSize = minOf(length, 65557).toInt()
        val tail = ByteArray(tailSize)
        reader.seek(length - tailSize)
        reader.readFully(tail)
        var end = -1
        for (position in tailSize - 22 downTo 0) {
            if (u32(tail, position) == 0x06054b50L && position + 22 + u16(tail, position + 20) == tailSize) {
                end = position
                break
            }
        }
        if (end < 0) invalid()
        val count = u16(tail, end + 10)
        val centralBytes = u32(tail, end + 12)
        val centralOffset = u32(tail, end + 16)
        if (u16(tail, end + 4) != 0 || u16(tail, end + 6) != 0 || u16(tail, end + 8) != count ||
            count == 65535 || centralOffset == 0xffffffffL || centralBytes == 0xffffffffL)
            throw ImportRejected("unsupported_zip", "Use a single-disk ZIP archive without ZIP64 or encryption.")
        if (count > limits.maxEntries || centralBytes > 32L * 1024 * 1024)
            throw ImportRejected("too_many_files", "ZIP metadata exceeds the safe-import limit.")
        val centralEnd = length - tailSize + end
        if (centralOffset + centralBytes != centralEnd) invalid()
        reader.seek(centralOffset)
        val header = ByteArray(46)
        var expanded = 0L
        repeat(count) {
            if (reader.filePointer + 46 > centralEnd) invalid()
            reader.readFully(header)
            if (u32(header, 0) != 0x02014b50L) invalid()
            val flags = u16(header, 8)
            val method = u16(header, 10)
            val size = u32(header, 24)
            val compressed = u32(header, 20)
            val externalMode = (u32(header, 38) shr 16).toInt() and 0xf000
            if (flags and 1 != 0 || method !in listOf(0, 8) || u16(header, 34) != 0 ||
                size == 0xffffffffL || compressed == 0xffffffffL || u32(header, 42) == 0xffffffffL)
                throw ImportRejected("unsupported_zip", "Use a single-disk ZIP archive without ZIP64 or encryption.")
            // UNIX link/device/FIFO entries are rejected, never followed or recreated.
            if (header[5].toInt() and 255 == 3 && externalMode !in listOf(0, 0x8000, 0x4000))
                throw ImportRejected("unsafe_link", "ZIP links and special files are not supported.")
            expanded += size
            if (size > limits.maxFileBytes || expanded > limits.maxBytes)
                throw ImportRejected("import_too_large", "ZIP expanded data exceeds the safe-import limit.")
            if (size > 0 && (compressed == 0L || size > compressed * limits.maxRatio))
                throw ImportRejected("archive_ratio", "Archive compression ratio exceeds the safe-import limit.")
            val variable = u16(header, 28) + u16(header, 30) + u16(header, 32)
            if (reader.filePointer + variable > centralEnd) invalid()
            reader.seek(reader.filePointer + variable)
        }
        if (reader.filePointer != centralEnd) invalid()
        count
    }
    private fun u16(bytes: ByteArray, offset: Int): Int = (bytes[offset].toInt() and 255) or ((bytes[offset + 1].toInt() and 255) shl 8)
    private fun u32(bytes: ByteArray, offset: Int): Long = u16(bytes, offset).toLong() or (u16(bytes, offset + 2).toLong() shl 16)
    private fun invalid(): Nothing = throw ImportRejected("invalid_archive", "ZIP data is incomplete or corrupt.")
}
