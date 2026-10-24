package com.nexuspc.app.library

import java.io.File
import java.io.RandomAccessFile
import java.security.MessageDigest

data class PeExecutable(val relativePath: String, val architecture: String, val sha256: String)

/** A structural PE check and content fingerprint, not a signature, malware or compatibility verdict. */
object PeInspector {
    fun inspect(root: File, relative: String, checkpoint: () -> Unit = {}): PeExecutable? {
        if (!relative.endsWith(".exe", ignoreCase = true)) return null
        val file = ImportPolicy.child(root, relative)
        if (!file.isFile) return null
        val architecture = RandomAccessFile(file, "r").use { reader ->
            if (reader.length() < 64 || reader.readUnsignedByte() != 0x4d || reader.readUnsignedByte() != 0x5a) return null
            reader.seek(0x3c)
            val offset = Integer.reverseBytes(reader.readInt()).toLong() and 0xffffffffL
            if (offset < 64 || offset > reader.length() - 26) return null
            reader.seek(offset)
            if (reader.readInt() != 0x50450000) return null
            val machine = java.lang.Short.reverseBytes(reader.readShort()).toInt() and 0xffff
            val sections = java.lang.Short.reverseBytes(reader.readShort()).toInt() and 0xffff
            reader.skipBytes(12)
            val optionalSize = java.lang.Short.reverseBytes(reader.readShort()).toInt() and 0xffff
            val characteristics = java.lang.Short.reverseBytes(reader.readShort()).toInt() and 0xffff
            val magic = java.lang.Short.reverseBytes(reader.readShort()).toInt() and 0xffff
            if (characteristics and 0x0002 == 0 || characteristics and 0x2000 != 0 ||
                sections !in 1..96 || offset + 24 + optionalSize + sections * 40 > reader.length()) return null
            when {
                machine == 0x8664 && magic == 0x20b && optionalSize >= 112 -> "x86_64"
                machine == 0x14c && magic == 0x10b && optionalSize >= 96 -> "x86"
                else -> return null
            }
        }
        val hash = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(128 * 1024)
            while (true) {
                checkpoint()
                val count = input.read(buffer)
                if (count < 0) break
                hash.update(buffer, 0, count)
            }
        }
        return PeExecutable(relative, architecture, hash.digest().joinToString("") { "%02x".format(it) })
    }
}
