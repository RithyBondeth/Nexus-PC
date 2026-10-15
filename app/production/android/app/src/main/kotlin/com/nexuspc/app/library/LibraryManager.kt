package com.nexuspc.app.library

import android.content.Context
import android.net.Uri
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import com.nexuspc.app.FlutterError
import com.nexuspc.app.ImportKind
import com.nexuspc.app.ImportProgress
import com.nexuspc.app.ImportState
import java.io.File
import java.util.concurrent.Executors

/** One process-lifetime owner: replacing a Flutter engine cannot race another worker's recovery. */
class LibraryManager private constructor(private val context: Context) {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var storage: LibraryStore? = null
    private var state = ImportState.IDLE
    private var code = "idle"
    private var message = "Choose a game folder or ZIP to import."
    private var jobId: String? = null
    private var gameId: String? = null
    private var control: CopyControl? = null
    private var signal: CancellationSignal? = null
    private var cancellationRequested = false

    @Synchronized fun progress() = ImportProgress(state, code, message,
        control?.bytes ?: 0, control?.files ?: 0, jobId, gameId)
    @Synchronized private fun active() = state in listOf(ImportState.CHOOSING, ImportState.COPYING, ImportState.COMMITTING)
    @Synchronized fun begin(): ImportProgress {
        if (active()) throw FlutterError("import_busy", "Wait for the current import or cancel it.")
        if (code == "cleanup_pending") throw FlutterError("cleanup_pending", "Restart Nexus-PC to recover the unfinished copy before another import.")
        state = ImportState.CHOOSING; code = "choosing"; message = "Choose a source in the system picker."
        jobId = LibraryStore.newId(); gameId = null; control = CopyControl(); signal = CancellationSignal(); cancellationRequested = false
        return progress()
    }
    @Synchronized fun pickerFailed(id: String) {
        if (jobId == id && state == ImportState.CHOOSING) {
            state = ImportState.FAILED; code = "picker_unavailable"; message = "The system picker could not open. Try again."
        }
    }
    @Synchronized fun pickerCancelled(id: String) {
        if (jobId == id && state == ImportState.CHOOSING) cancel(id)
    }
    @Synchronized fun cancel(id: String) {
        if (jobId != id) throw FlutterError("invalid_job", "This import is no longer active.")
        if (state == ImportState.CHOOSING) {
            state = ImportState.CANCELLED; code = "cancelled"; message = "Import cancelled. No game was added."
        } else if (state == ImportState.COPYING && !cancellationRequested) {
            cancellationRequested = true; message = "Cancelling import…"
            control?.cancel()
            val pendingSignal = signal
            Thread({ pendingSignal?.cancel() }, "nexus-provider-cancel").start()
        }
        // Publication is deliberately non-cancellable; an already committed game is retained.
    }
    @Synchronized fun selected(id: String, uri: Uri, kind: ImportKind) {
        if (id != jobId || state != ImportState.CHOOSING) return
        state = ImportState.COPYING; code = "copying"; message = "Copying and validating. Keep Nexus-PC open."
        val copying = control!!
        val providerSignal = signal!!
        worker.execute {
            var store: LibraryStore? = null
            try {
                store = store()
                copying.checkpoint()
                val stage = store.createStage(id)
                val copier = SafeCopy(File(stage, "content"), copying)
                val archive = File(stage, "source.zip")
                val title = DocumentCopy(context, providerSignal).copy(uri, kind, copier, archive)
                if (archive.exists() && !archive.delete()) throw java.io.IOException("Could not remove staged ZIP")
                val result = copier.finish()
                synchronized(this) {
                    copying.checkpoint()
                    state = ImportState.COMMITTING; code = "committing"; message = "Saving the validated copy…"
                }
                val game = store.publish(id, title, result)
                synchronized(this) {
                    gameId = game.id; state = ImportState.COMPLETED; code = "completed"; message = "Imported copy saved to your library."
                }
            } catch (error: Exception) {
                var cleanupFailed = false
                try { store?.discardStage(id) } catch (_: Exception) { cleanupFailed = true }
                synchronized(this) {
                    state = if (cancellationRequested && !cleanupFailed) ImportState.CANCELLED else ImportState.FAILED
                    code = if (cleanupFailed) "cleanup_pending" else if (cancellationRequested) "cancelled" else (error as? ImportRejected)?.code ?: "import_failed"
                    message = if (cleanupFailed) "Import stopped. Restart Nexus-PC to recover the unfinished copy."
                        else if (cancellationRequested) "Import cancelled. No game was added."
                        else (error as? ImportRejected)?.message ?: "Import failed. Check the source and free storage, then try again."
                }
            }
        }
    }
    fun <T> access(callback: (Result<T>) -> Unit, operation: (LibraryStore) -> T) {
        synchronized(this) {
            if (active()) { callback(Result.failure(FlutterError("import_busy", "Wait for the current import to finish."))); return }
            worker.execute {
                val result = try { Result.success(operation(store())) }
                    catch (error: Exception) { Result.failure<T>(FlutterError((error as? ImportRejected)?.code ?: "library_error",
                        (error as? ImportRejected)?.message ?: "Library operation failed. Try again or restart Nexus-PC.")) }
                main.post { callback(result) }
            }
        }
    }
    private fun store(): LibraryStore = storage ?: LibraryStore(context).also { storage = it }
    companion object {
        @Volatile private var instance: LibraryManager? = null
        fun get(context: Context): LibraryManager = instance ?: synchronized(this) {
            instance ?: LibraryManager(context.applicationContext).also { instance = it }
        }
    }
}
