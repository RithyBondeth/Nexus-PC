package com.nexuspc.app.library

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.file.Files
import java.security.MessageDigest
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class ImportSafetyTest {
    @get:Rule val temporary = TemporaryFolder()
    private val small = ImportLimits(maxBytes = 4096, maxFileBytes = 2048, maxArchiveBytes = 8192, reserveBytes = 0)
    private fun root() = temporary.newFolder()
    private fun copy(limits: ImportLimits = small): Pair<File, SafeCopy> {
        val directory = root()
        return directory to SafeCopy(directory, CopyControl(limits))
    }
    private fun rejects(code: String, operation: () -> Unit) {
        try { operation(); fail("Expected $code") } catch (error: ImportRejected) { assertEquals(code, error.code) }
    }
    @Test fun rejectsUnsafeWindowsAndTraversalNames() {
        for (name in listOf("../outside.exe", "/outside.exe", "C:/bad.exe", "a\\b.exe", "a//b.exe", "./a.exe",
            "a/../b.exe", "a\u0000b", "a\nb", "CON.exe", "aux/data", "LPT9.bin", "dir/file.", "dir/file ", "a:b", "a?b", "a\u202eb")) {
            rejects("unsafe_path") { ImportPolicy.path(name) }
        }
        assertEquals("Games/日本語/game.exe", ImportPolicy.path("Games/日本語/game.exe"))
    }
    @Test fun enforcesDepthAndLength() {
        rejects("unsafe_path") { ImportPolicy.path(List(33) { "dir" }.joinToString("/")) }
        rejects("unsafe_path") { ImportPolicy.path("a".repeat(256)) }
        rejects("unsafe_path") { ImportPolicy.path(List(10) { "a".repeat(120) }.joinToString("/")) }
    }
    @Test fun canonicalContainmentDoesNotFollowSymlink() {
        val destination = root()
        val outside = root()
        Files.createSymbolicLink(File(destination, "link").toPath(), outside.toPath())
        rejects("unsafe_path") { ImportPolicy.child(destination, "link/escape.exe") }
        assertEquals(0, outside.list()!!.size)
    }
    @Test fun validatesOwnedIdentifiersAndTitles() {
        val id = java.util.UUID.randomUUID().toString()
        assertEquals(id, ImportPolicy.id(id))
        for (bad in listOf("../games", "", "root", id + "/child")) rejects("invalid_game") { ImportPolicy.id(bad) }
        assertEquals("Game title", ImportPolicy.title(" Game title "))
        for (bad in listOf(" ", "A\nB", "a".repeat(121))) rejects("invalid_title") { ImportPolicy.title(bad) }
    }
    @Test fun rejectsDuplicateCaseAndUnicodeAliases() {
        val names = ImportNames(small)
        names.add("Game/a.exe", false)
        rejects("name_collision") { names.add("game/b.dat", false) }
        val unicode = ImportNames(small)
        unicode.add("café.exe", false)
        rejects("name_collision") { unicode.add("cafe\u0301.exe", false) }
    }
    @Test fun allowsExplicitDirectoryAfterImplicitParentButNotFileDirectoryConflict() {
        val names = ImportNames(small)
        names.add("Game/a.exe", false)
        names.add("Game", true)
        rejects("name_collision") { names.add("Game", true) }
        val other = ImportNames(small)
        other.add("Game", false)
        rejects("name_collision") { other.add("Game/a.exe", false) }
    }
    @Test fun boundsEntryCount() {
        val names = ImportNames(small.copy(maxEntries = 1))
        names.add("a.exe", false)
        rejects("too_many_files") { names.add("b.dat", false) }
    }
    @Test fun structurallyChecksPeAndHashesEntireExecutable() {
        val directory = root()
        val pe = pe()
        File(directory, "game.exe").writeBytes(pe)
        val result = PeInspector.inspect(directory, "game.exe")!!
        assertEquals("x86_64", result.architecture)
        assertEquals(MessageDigest.getInstance("SHA-256").digest(pe).joinToString("") { "%02x".format(it) }, result.sha256)
        File(directory, "legacy.exe").writeBytes(pe(machine = 0x14c, magic = 0x10b))
        assertEquals("x86", PeInspector.inspect(directory, "legacy.exe")!!.architecture)
    }
    @Test fun rejectsDisguisedTruncatedDllAndUnsupportedPe() {
        val directory = root()
        for ((index, bytes) in listOf("not a PE".toByteArray(), pe().copyOf(65), pe(machine = 0xaa64),
            pe(characteristics = 0x2002), pe(characteristics = 0), pe(magic = 0x10b)).withIndex()) {
            val name = "$index.exe"
            File(directory, name).writeBytes(bytes)
            assertNull(PeInspector.inspect(directory, name))
        }
    }
    @Test fun peOffsetsCannotEscapeFile() {
        val directory = root()
        for (offset in listOf(0, 63, Int.MAX_VALUE, -1)) {
            val bytes = pe()
            ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).putInt(0x3c, offset)
            File(directory, "game.exe").writeBytes(bytes)
            assertNull(PeInspector.inspect(directory, "game.exe"))
        }
    }
    @Test fun copiesPeAndDataWithStableContentFingerprint() {
        val (destination, importer) = copy()
        importer.file("game.exe", ByteArrayInputStream(pe()))
        importer.file("data/config.txt", ByteArrayInputStream("original".toByteArray()))
        val result = importer.finish()
        assertEquals(2, result.files)
        assertEquals("original", File(destination, "data/config.txt").readText())
        assertEquals(1, result.executables.size)
        val (_, reverse) = copy()
        reverse.file("data/config.txt", ByteArrayInputStream("original".toByteArray()))
        reverse.file("game.exe", ByteArrayInputStream(pe()))
        assertEquals(result.contentHash, reverse.finish().contentHash)
    }
    @Test fun rejectsActualBytesEvenWhenDeclaredSizeLies() {
        val (_, importer) = copy(small.copy(maxFileBytes = 8))
        rejects("file_too_large") { importer.file("data.bin", ByteArrayInputStream(ByteArray(9)), expectedBytes = 1) }
        val (_, mismatch) = copy()
        rejects("invalid_archive") { mismatch.file("data.bin", ByteArrayInputStream(ByteArray(9)), expectedBytes = 1) }
    }
    @Test fun rejectsActualAggregateBytes() {
        val (_, importer) = copy(small.copy(maxBytes = 15))
        importer.file("one", ByteArrayInputStream(ByteArray(8)))
        rejects("import_too_large") { importer.file("two", ByteArrayInputStream(ByteArray(8))) }
    }
    @Test fun validatesCrcRatherThanTrustingZipStream() {
        val (_, importer) = copy()
        rejects("invalid_archive") { importer.file("data", ByteArrayInputStream(byteArrayOf(1, 2)), 2, 0) }
    }
    @Test fun cancelledCopyNeverAddsAnExecutable() {
        val (_, importer) = copy()
        importer.control.cancel()
        rejects("cancelled") { importer.file("game.exe", ByteArrayInputStream(pe())) }
        assertEquals(0, importer.control.files)
    }
    @Test fun requiresARealSupportedExecutable() {
        val (_, importer) = copy()
        importer.file("pretend.exe", ByteArrayInputStream("fake".toByteArray()))
        rejects("no_executable") { importer.finish() }
    }
    @Test fun cancellationDuringCopyStopsBeforePublishingAFile() {
        val (_, importer) = copy()
        val input = object : ByteArrayInputStream(pe()) {
            override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
                val count = super.read(buffer, offset, minOf(length, 16))
                importer.control.cancel()
                return count
            }
        }
        rejects("cancelled") { importer.file("game.exe", input) }
        assertEquals(0, importer.control.files)
        assertTrue(importer.control.bytes < pe().size)
    }
    @Test fun boundsExecutableCandidates() {
        val (_, importer) = copy(small.copy(maxExecutables = 1))
        importer.file("a.exe", ByteArrayInputStream(pe()))
        importer.file("b.exe", ByteArrayInputStream(pe()))
        rejects("too_many_executables") { importer.finish() }
    }
    @Test fun importsZipWithEquivalentFolderFingerprint() {
        val (destination, importer) = copy()
        val archive = zip("game.exe" to pe(), "data/readme.txt" to "safe".toByteArray())
        importer.archive(ByteArrayInputStream(archive), temporary.newFile())
        assertArrayEquals(pe(), File(destination, "game.exe").readBytes())
        val (_, folder) = copy()
        folder.file("game.exe", ByteArrayInputStream(pe()))
        folder.file("data/readme.txt", ByteArrayInputStream("safe".toByteArray()))
        assertEquals(folder.finish().contentHash, importer.finish().contentHash)
    }
    @Test fun rejectsZipTraversalAndCaseCollision() {
        val (_, traversal) = copy()
        rejects("unsafe_path") { traversal.archive(ByteArrayInputStream(zip("../escape.exe" to pe())), temporary.newFile()) }
        val (_, collision) = copy()
        rejects("name_collision") { collision.archive(ByteArrayInputStream(zip("A.exe" to pe(), "a.exe" to pe())), temporary.newFile()) }
    }
    @Test fun rejectsTruncatedAndNonZipData() {
        for (bytes in listOf("not zip".toByteArray(), zip("game.exe" to pe()).dropLast(5).toByteArray())) {
            val (_, importer) = copy()
            rejects("invalid_archive") { importer.archive(ByteArrayInputStream(bytes), temporary.newFile()) }
        }
    }
    @Test fun boundsCompressedMetadataBeforeParserAllocation() {
        val archive = temporary.newFile()
        archive.writeBytes(zip("game.exe" to pe(), "data" to byteArrayOf(1)))
        rejects("too_many_files") { ZipPreflight.validate(archive, small.copy(maxEntries = 1)) }
        val bytes = archive.readBytes()
        ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).putInt(bytes.size - 22 + 12, 33 * 1024 * 1024)
        archive.writeBytes(bytes)
        rejects("too_many_files") { ZipPreflight.validate(archive, small) }
    }
    @Test fun rejectsEncryptedZip64AndUnixSymlinkMetadata() {
        for ((offset, expected) in listOf(8 to 1 to "unsupported_zip", 38 to (0xa000 shl 16) to "unsafe_link")) {
            val bytes = zip("game.exe" to pe())
            val central = centralOffset(bytes)
            bytes[central + 5] = 3
            val buffer = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
            if (offset.first == 8) buffer.putShort(central + offset.first, offset.second.toShort())
            else buffer.putInt(central + offset.first, offset.second)
            val archive = temporary.newFile()
            archive.writeBytes(bytes)
            rejects(expected) { ZipPreflight.validate(archive, small) }
        }
        val archive = temporary.newFile()
        val bytes = zip("game.exe" to pe())
        ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).putShort(bytes.size - 22 + 10, (-1).toShort())
        archive.writeBytes(bytes)
        rejects("unsupported_zip") { ZipPreflight.validate(archive, small) }
    }
    @Test fun rejectsHighCompressionRatioBeforeExtraction() {
        val archive = temporary.newFile()
        archive.writeBytes(zip("bomb.dat" to ByteArray(128 * 1024)))
        rejects("archive_ratio") { ZipPreflight.validate(archive, ImportLimits(reserveBytes = 0)) }
    }
    companion object {
        fun pe(machine: Int = 0x8664, magic: Int = 0x20b, characteristics: Int = 2): ByteArray {
            val bytes = ByteArray(512)
            val buffer = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
            bytes[0] = 0x4d; bytes[1] = 0x5a
            buffer.putInt(0x3c, 64); buffer.putInt(64, 0x00004550)
            buffer.putShort(68, machine.toShort()); buffer.putShort(70, 1)
            buffer.putShort(84, (if (magic == 0x10b) 224 else 240).toShort())
            buffer.putShort(86, characteristics.toShort()); buffer.putShort(88, magic.toShort())
            return bytes
        }
        fun zip(vararg files: Pair<String, ByteArray>): ByteArray = ByteArrayOutputStream().use { output ->
            ZipOutputStream(output).use { zip ->
                for ((name, bytes) in files) { zip.putNextEntry(ZipEntry(name)); zip.write(bytes); zip.closeEntry() }
            }
            output.toByteArray()
        }
        private fun centralOffset(bytes: ByteArray): Int = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).getInt(bytes.size - 22 + 16)
    }
}
