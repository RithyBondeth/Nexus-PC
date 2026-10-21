package com.nexuspc.app.runtime

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.system.Os
import androidx.preference.PreferenceManager
import com.nexuspc.app.*
import com.nexuspc.app.library.LibraryManager
import com.winlator.container.ContainerManager
import com.winlator.core.EnvVars
import com.winlator.core.NexusPackagedRuntime
import com.winlator.core.TarCompressorUtils
import com.winlator.xenvironment.RootFS
import com.winlator.xenvironment.RootFSInstaller
import org.json.JSONObject
import java.io.File
import java.lang.ref.WeakReference
import java.util.concurrent.Executors

/** Experimental single foreground session; no background-service or sandbox claim. */
class WindowsRuntime(activity: Activity) : RuntimeBackend {
    private val activity = WeakReference(activity)
    private val context = activity.applicationContext
    override var onStatus: ((RuntimeStatus) -> Unit)? = null
    private val listener: (RuntimeStatus) -> Unit = { onStatus?.invoke(it) }
    init {
        if (Os.sysconf(android.system.OsConstants._SC_PAGESIZE) !in longArrayOf(4096L, 16384L) || Process.myUid() >= 100000) {
            Session.update(RuntimeState.UNAVAILABLE, "runtime_unsupported_device", "This experimental runtime requires 4 KB or 16 KB pages and the primary Android user.")
        }
        Session.listeners.add(listener)
    }
    override fun status() = Session.state
    override fun prepare(request: LaunchRequest, callback: (Result<RuntimeStatus>) -> Unit) = start(request, false, callback)
    override fun launch(request: LaunchRequest, callback: (Result<RuntimeStatus>) -> Unit) = start(request, true, callback)
    private fun start(request: LaunchRequest, launch: Boolean, callback: (Result<RuntimeStatus>) -> Unit) {
        if (Session.state.state == RuntimeState.UNAVAILABLE) {
            callback(Result.failure(FlutterError("runtime_unsupported_device", Session.state.message))); return
        }
        val owner = activity.get()
        if (owner == null || owner.isFinishing || Session.busy || Session.lease != null) {
            callback(Result.failure(FlutterError("runtime_busy", "The runtime is busy or its screen has closed."))); return
        }
        Session.generation++
        Session.update(RuntimeState.PREPARING, "runtime_preparing", "Preparing the pinned experimental Windows runtime…")
        val library = LibraryManager.get(context)
        library.acquireRuntime(request.gameId, request.executableRelativePath) { selection ->
            selection.fold(onSuccess = { (lease, executable) ->
                Session.lease = lease
                Session.library = library
                provision(context) { prepared ->
                    prepared.fold(onSuccess = { containerId ->
                        if (launch && activity.get()?.isFinishing == false) {
                            try {
                                val prefs = PreferenceManager.getDefaultSharedPreferences(context)
                                prefs.edit().putString("box64_version", "0.4.4").putInt("box64_logs", 1)
                                    .putBoolean("enable_wine_debug", true).apply()
                                owner.startActivity(Intent(owner, RuntimeDisplayActivity::class.java)
                                    .putExtra("container_id", containerId).putExtra("exec_path", executable.path)
                                    .putExtra("nexus_smoke", true).putExtra("librarySession", true)
                                    .putExtra("autoInput", owner.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0 && owner.intent.getBooleanExtra("runtimeAutoInput", false)))
                                Session.update(RuntimeState.RUNNING, "runtime_started", "Windows process requested. Compatibility is unverified.")
                                callback(Result.success(Session.state))
                            } catch (error: Exception) { Session.fail(error, callback) }
                        } else {
                            Session.release()
                            Session.update(RuntimeState.IDLE, "runtime_ready", "Pinned Wine / Box64 runtime prepared.")
                            callback(Result.success(Session.state))
                        }
                    }, onFailure = { Session.fail(it, callback) })
                }
            }, onFailure = { Session.fail(it, callback) })
        }
    }
    override fun stop(callback: (Result<RuntimeStatus>) -> Unit) {
        if (Session.state.state == RuntimeState.PREPARING) {
            callback(Result.failure(FlutterError("runtime_busy", "Wait for runtime preparation to finish."))); return
        }
        Session.update(RuntimeState.STOPPING, "runtime_stopping", "Stopping the Windows session…")
        Session.display.get()?.finish()
        Session.drain(context) { callback(Result.success(Session.state)) }
    }
    override fun close() { Session.listeners.remove(listener); onStatus = null }

    companion object {
        private val worker = Executors.newSingleThreadExecutor()
        private val main = Handler(Looper.getMainLooper())
        fun provision(context: Context, callback: (Result<Int>) -> Unit) {
            worker.execute {
                try {
                    val root = RootFS.find(context)
                    if (!root.isValid) {
                        root.rootDir.mkdirs()
                        check(TarCompressorUtils.extract(TarCompressorUtils.Type.ZSTD, context,
                            RootFSInstaller.FILENAME, root.rootDir)) { "Runtime extraction failed" }
                        root.createRFSVersionFile(RootFSInstaller.LATEST_VERSION.toInt())
                    }
                    NexusPackagedRuntime.install(context)
                    val manager = ContainerManager(context)
                    main.post {
                        // Prefix state created by the old 4 KB-only interpreter must not be
                        // reused on a 16 KB host. Keep legacy prefixes intact, including
                        // C: saves, and select one stable prefix per host-page profile.
                        val pageSize = Os.sysconf(android.system.OsConstants._SC_PAGESIZE)
                        val profile = "host-pages-v2-$pageSize"
                        val existing = manager.containers.firstOrNull {
                            it.name == "Nexus runtime $profile" && it.getExtra("nexusRuntimeProfile") == profile
                        }
                        if (existing != null) {
                            // Esync in this Wine bundle maps shared objects at 4 KB
                            // file offsets. Use Wine server synchronization on 16 KB.
                            if (pageSize == 16384L) {
                                existing.envVars = EnvVars(existing.envVars).apply { put("WINEESYNC", "0") }.toString()
                                existing.saveData()
                            }
                            callback(Result.success(existing.id))
                        }
                        else manager.createContainerAsync(JSONObject().apply {
                            put("name", "Nexus runtime $profile"); put("screenSize", "800x600")
                            put("extraData", JSONObject().put("nexusRuntimeProfile", profile))
                            put("graphicsDriver", "vortek,gladio"); put("dxwrapper", "wined3d")
                            put("wincomponents", "direct3d=0,directsound=0,directmusic=0,directshow=0,directplay=0,xaudio=0,vcrun2005=0,vcrun2010=0,wmdecoder=0")
                            put("drives", ""); put("envVars", "BOX64_LOG=1 BOX64_DYNAREC=0 WINEDEBUG=+timestamp,+seh" + if (pageSize == 16384L) " WINEESYNC=0" else "")
                        }) { container ->
                            callback(if (container == null) Result.failure(IllegalStateException("Container preparation failed")) else Result.success(container.id))
                        }
                    }
                } catch (error: Exception) { main.post { callback(Result.failure(error)) } }
            }
        }
    }
}

internal object Session {
    @Volatile var state = RuntimeStatus(RuntimeState.IDLE, "runtime_experimental", "Experimental Wine / Box64 build. x86-64 GDI testing only.", System.currentTimeMillis())
    val listeners = java.util.concurrent.CopyOnWriteArrayList<(RuntimeStatus) -> Unit>()
    @Volatile var generation = 0
    var lease: String? = null
    var library: LibraryManager? = null
    var display = WeakReference<RuntimeDisplayActivity>(null)
    val busy get() = state.state in listOf(RuntimeState.PREPARING, RuntimeState.RUNNING, RuntimeState.STOPPING)
    fun update(value: RuntimeState, code: String, message: String) {
        state = RuntimeStatus(value, code, message, System.currentTimeMillis())
        listeners.forEach { it(state) }
    }
    fun release() { lease?.let { library?.releaseRuntime(it) }; lease = null; library = null }
    fun fail(error: Throwable, callback: (Result<RuntimeStatus>) -> Unit) {
        release()
        update(RuntimeState.FAILED, "runtime_failed", (error as? FlutterError)?.message ?: error.message ?: "Runtime operation failed.")
        callback(Result.failure(if (error is FlutterError) error else FlutterError("runtime_failed", state.message)))
    }
    private val cleanup = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    fun drain(context: Context, done: () -> Unit = {}) {
        val expected = generation
        cleanup.execute {
            if (generation != expected) { main.post { done() }; return@execute }
            val binary = File(context.applicationInfo.nativeLibraryDir, "libnexus_box64.so").canonicalPath
            // Match both ownership and the exact packaged executable. Never use
            // upstream's broad PID/name heuristic to terminate other applications.
            fun ownedProcesses(): List<Int> = File("/proc").listFiles()?.filter { it.name.all(Char::isDigit) }?.mapNotNull { proc ->
                try {
                    if (Os.stat(proc.path).st_uid == Process.myUid() && Os.readlink("${proc.path}/exe") == binary) proc.name.toInt() else null
                } catch (_: Exception) { null }
            } ?: emptyList()
            ownedProcesses().forEach { try { Process.killProcess(it) } catch (_: Exception) { } }
            val deadline = android.os.SystemClock.elapsedRealtime() + 3000
            while (ownedProcesses().isNotEmpty() && android.os.SystemClock.elapsedRealtime() < deadline) Thread.sleep(50)
            val drained = ownedProcesses().isEmpty()
            main.post {
                if (generation != expected) { done(); return@post }
                generation++
                if (!drained) {
                    update(RuntimeState.FAILED, "runtime_cleanup_pending", "Windows processes did not stop. Retry Stop game or restart Nexus-PC.")
                    done()
                    return@post
                }
                release()
                if (state.state != RuntimeState.FAILED) update(RuntimeState.IDLE, "runtime_stopped", "Windows session stopped.")
                done()
            }
        }
    }
}
