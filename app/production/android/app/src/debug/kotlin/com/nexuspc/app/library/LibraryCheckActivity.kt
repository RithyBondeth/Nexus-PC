package com.nexuspc.app.library

import android.app.Activity
import android.database.sqlite.SQLiteDatabase
import android.os.Bundle
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.file.Files
import java.nio.file.SimpleFileVisitor
import java.nio.file.FileVisitResult
import java.nio.file.Path
import java.nio.file.attribute.BasicFileAttributes
import java.util.concurrent.atomic.AtomicBoolean

/** Debug-only Android integration checks. Synthetic PE headers are never executed. */
class LibraryCheckActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val checkId = intent.getStringExtra("checkId")
        if (savedInstanceState != null || checkId == null || !Regex("[A-Za-z0-9-]{1,64}").matches(checkId) ||
            !running.compareAndSet(false, true)) { finish(); return }
        val context = applicationContext
        Thread({
            val report = JSONObject().put("checkId", checkId).put("androidApi", android.os.Build.VERSION.SDK_INT)
            val checks = JSONArray()
            val sandbox = File(context.noBackupFilesDir.canonicalFile, "library-check-${LibraryStore.newId()}")
            var store: LibraryStore? = null
            try {
                check(sandbox.mkdir())
                val root = File(sandbox, "database")
                val source = File(sandbox, "source").apply { check(mkdir()) }
                val original = File(source, "game.exe").apply { writeBytes(pe()) }
                fun open(): LibraryStore = LibraryStore(context, root).also { store = it }
                fun reopen(): LibraryStore { store?.close(); return open() }
                fun verify(name: String, assertion: () -> Unit) { assertion(); checks.put(name) }
                fun publish(title: String, multiple: Boolean = false): String {
                    val current = store!!
                    val id = LibraryStore.newId()
                    val stage = current.createStage(id)
                    val copier = SafeCopy(File(stage, "content"), CopyControl(ImportLimits(reserveBytes = 0)))
                    copier.file("game.exe", original.inputStream())
                    if (multiple) copier.file("tools/other.exe", pe(legacy = true).inputStream())
                    current.publish(id, title, copier.finish())
                    return id
                }
                open()
                val first = publish("100%_Game")
                verify("publishAndSelectSingle") {
                    val details = store!!.details(first)
                    check(details.game.title == "100%_Game" && details.game.fileCount == 1L && details.game.sizeBytes == 512L)
                    check(details.game.executableRelativePath == "game.exe" && details.game.architecture == "x86_64")
                    check(details.game.sha256 == PeInspector.inspect(source, "game.exe")!!.sha256)
                }
                verify("sqliteReopenPersistence") {
                    check(reopen().list(0, 50, "").games.single().id == first)
                    check(File(root, "games/$first/content/game.exe").readBytes().contentEquals(pe()))
                }
                verify("literalParameterizedSearch") {
                    check(store!!.list(0, 50, "%_").total == 1L)
                    check(store!!.list(0, 50, "' OR 1=1 --").total == 0L)
                    check(store!!.list(1, 1, "").games.isEmpty())
                    rejects("invalid_argument") { store!!.list(0, 51, "") }
                }
                verify("duplicatePreservesExistingAndSource") {
                    val id = LibraryStore.newId()
                    val stage = store!!.createStage(id)
                    val copier = SafeCopy(File(stage, "content"), CopyControl(ImportLimits(reserveBytes = 0)))
                    copier.file("game.exe", original.inputStream())
                    rejects("duplicate_game") { store!!.publish(id, "Duplicate", copier.finish()) }
                    store!!.discardStage(id)
                    check(store!!.list(0, 50, "").total == 1L && original.readBytes().contentEquals(pe()))
                    check(!stage.exists() && !File(root, "owners/$id").exists())
                }
                val second = publish("Multiple", multiple = true)
                verify("validatedExecutableAndTitleUpdate") {
                    check(store!!.details(second).game.executableRelativePath == null)
                    val updated = store!!.update(second, " Renamed ", "tools/other.exe")
                    check(updated.title == "Renamed" && updated.architecture == "x86")
                    rejects("invalid_title") { store!!.update(second, " ", "game.exe") }
                    rejects("invalid_executable") { store!!.update(second, "Bad", "absent.exe") }
                    rejects("unsafe_path") { store!!.update(second, "Bad", "../game.exe") }
                    check(reopen().details(second).game.title == "Renamed")
                }
                verify("changedExecutableRejected") {
                    val executable = File(root, "games/$second/content/game.exe")
                    executable.appendBytes(byteArrayOf(1))
                    rejects("executable_changed") { store!!.update(second, "Bad", "game.exe") }
                    check(store!!.details(second).game.title == "Renamed")
                }
                verify("removeNeverFollowsPayloadLinks") {
                    val sentinel = File(source, "keep.txt").apply { writeText("original") }
                    Files.createSymbolicLink(File(root, "games/$second/content/link").toPath(), source.toPath())
                    store!!.remove(second)
                    check(sentinel.readText() == "original" && original.readBytes().contentEquals(pe()))
                    check(!File(root, "games/$second").exists() && store!!.list(0, 50, "").total == 1L)
                    rejects("game_missing") { store!!.details(second) }
                    rejects("invalid_game") { store!!.remove("../source") }
                }
                verify("incompleteStageRecovery") {
                    val id = LibraryStore.newId()
                    val stage = store!!.createStage(id)
                    File(stage, "content/partial.bin").writeText("partial")
                    reopen()
                    check(!stage.exists() && !File(root, "owners/$id").exists())
                    check(store!!.list(0, 50, "").total == 1L)
                }
                verify("renameBeforePublicationRecovery") {
                    val id = LibraryStore.newId()
                    val stage = store!!.createStage(id)
                    val orphan = File(root, "games/$id")
                    check(stage.renameTo(orphan))
                    reopen()
                    check(!orphan.exists() && !File(root, "owners/$id").exists())
                }
                verify("transactionFailureRollsBackCopy") {
                    val id = LibraryStore.newId()
                    val stage = store!!.createStage(id)
                    val invalid = CopyResult(1, 1, "unique-test-hash",
                        listOf(PeExecutable("same.exe", "x86", "a"), PeExecutable("same.exe", "x86", "a")))
                    var rejected = false
                    try { store!!.publish(id, "Rollback", invalid) } catch (_: android.database.sqlite.SQLiteConstraintException) { rejected = true }
                    check(rejected && !stage.exists() && !File(root, "games/$id").exists())
                    check(!File(root, "owners/$id").exists() && store!!.list(0, 50, "").total == 1L)
                }
                verify("deletionJournalRecovery") {
                    store!!.close(); store = null
                    SQLiteDatabase.openDatabase(File(root, "library.sqlite").path, null, SQLiteDatabase.OPEN_READWRITE).use {
                        it.execSQL("UPDATE games SET deleting=1 WHERE id=?", arrayOf(first))
                    }
                    check(File(root, "games/$first/content/game.exe").delete())
                    open()
                    check(store!!.list(0, 50, "").total == 0L)
                    check(!File(root, "games/$first").exists() && !File(root, "owners/$first").exists())
                }
                val third = publish("Ownership")
                verify("tamperedOwnershipFailsClosed") {
                    val marker = File(root, "owners/$third")
                    marker.writeText("x".repeat(36))
                    rejects("library_storage") { store!!.remove(third) }
                    check(File(root, "games/$third/content/game.exe").exists())
                    check(store!!.list(0, 50, "").total == 1L)
                    marker.writeText(third)
                    store!!.remove(third)
                    check(original.readBytes().contentEquals(pe()))
                }
                verify("truncatedUnusedMarkerRecovery") {
                    val id = LibraryStore.newId()
                    val marker = File(root, "owners/$id").apply { writeText(id.take(12)) }
                    reopen()
                    check(!marker.exists())
                }
                verify("jobOwnershipAndCleanupFailureLatch") {
                    // An isolated owner, with no IO tasks submitted and no real-library access.
                    val constructor = LibraryManager::class.java.getDeclaredConstructor(android.content.Context::class.java)
                    constructor.isAccessible = true
                    val owner = constructor.newInstance(context)
                    fun hostRejects(code: String, operation: () -> Unit) {
                        try { operation() } catch (error: com.nexuspc.app.FlutterError) { check(error.code == code); return }
                        error("Expected $code")
                    }
                    check(owner.progress().state == com.nexuspc.app.ImportState.IDLE)
                    val firstJob = owner.begin().jobId!!
                    hostRejects("import_busy") { owner.begin() }
                    hostRejects("invalid_job") { owner.cancel("stale") }
                    owner.cancel(firstJob)
                    check(owner.progress().state == com.nexuspc.app.ImportState.CANCELLED)
                    val secondJob = owner.begin().jobId!!
                    owner.pickerCancelled(firstJob)
                    check(owner.progress().state == com.nexuspc.app.ImportState.CHOOSING)
                    owner.cancel(secondJob)
                    // Fault-inject the cleanup failure without damaging a user's filesystem.
                    LibraryManager::class.java.getDeclaredField("code").apply { isAccessible = true }.set(owner, "cleanup_pending")
                    hostRejects("cleanup_pending") { owner.begin() }
                    check(owner.progress().code == "cleanup_pending")
                }
                report.put("passed", checks.length() == 14)
            } catch (error: Throwable) {
                report.put("passed", false).put("error", "${error.javaClass.simpleName}: ${error.message}")
                android.util.Log.e("NexusLibraryChecks", "Native checks failed", error)
            } finally {
                store?.close()
                // Only this freshly generated harness sandbox; never library-v1 or a caller-provided path.
                try {
                    if (sandbox.exists()) Files.walkFileTree(sandbox.toPath(), object : SimpleFileVisitor<Path>() {
                        override fun visitFile(file: Path, attrs: BasicFileAttributes): FileVisitResult {
                            Files.delete(file); return FileVisitResult.CONTINUE
                        }
                        override fun postVisitDirectory(dir: Path, error: java.io.IOException?): FileVisitResult {
                            if (error != null) throw error
                            Files.delete(dir); return FileVisitResult.CONTINUE
                        }
                    })
                } catch (_: Exception) { report.put("passed", false).put("cleanupFailed", true) }
                report.put("checks", checks)
                File(context.filesDir, "library-checks.json").writeText(report.toString(2))
                running.set(false)
                runOnUiThread { finish() }
            }
        }, "nexus-library-checks").start()
    }
    private fun rejects(code: String, operation: () -> Unit) {
        try { operation() } catch (error: ImportRejected) { check(error.code == code); return }
        error("Expected $code")
    }
    private fun pe(legacy: Boolean = false): ByteArray {
        val bytes = ByteArray(512)
        val buffer = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        bytes[0] = 0x4d; bytes[1] = 0x5a
        buffer.putInt(0x3c, 64); buffer.putInt(64, 0x00004550)
        buffer.putShort(68, (if (legacy) 0x14c else 0x8664).toShort()); buffer.putShort(70, 1)
        buffer.putShort(84, (if (legacy) 224 else 240).toShort()); buffer.putShort(86, 2)
        buffer.putShort(88, (if (legacy) 0x10b else 0x20b).toShort())
        return bytes
    }
    companion object { private val running = AtomicBoolean() }
}
