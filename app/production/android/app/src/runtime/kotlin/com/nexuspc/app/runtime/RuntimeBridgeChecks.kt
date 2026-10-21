package com.nexuspc.app.runtime

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.system.Os
import android.system.OsConstants
import com.nexuspc.app.*
import com.nexuspc.app.library.*
import com.winlator.xenvironment.RootFS
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/** Debug entry: imports only our original, bundled MIT smoke game, then removes it. */
object RuntimeBridgeChecks {
    private val running = AtomicBoolean()
    private val main = Handler(Looper.getMainLooper())
    @JvmStatic fun run(host: NexusHost, context: Context, checkId: String) {
        if (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE == 0 || !running.compareAndSet(false, true)) return
        val library = LibraryManager.get(context)
        val checks = JSONArray()
        val report = JSONObject().put("checkId", checkId)
            .put("androidApi", android.os.Build.VERSION.SDK_INT)
            .put("targetApi", context.applicationInfo.targetSdkVersion)
            .put("pageSize", Os.sysconf(OsConstants._SC_PAGESIZE))
        report.put("runtimeBuild", JSONObject(context.assets.open("nexus-runtime-build.json").bufferedReader().use { it.readText() }))
        var fixture: String? = null
        val marker = File(context.filesDir, "runtime-check-fixture.json")
        fun finish(failure: Throwable? = null) {
            if (failure != null) report.put("error", "${failure.javaClass.simpleName}: ${failure.message}")
            host.stopGame {
                val game = fixture
                if (game == null) {
                    report.put("passed", false).put("checks", checks)
                    File(context.filesDir, "runtime-bridge-checks.json").writeText(report.toString(2)); running.set(false)
                } else library.access<Unit>({ cleanup ->
                    report.put("passed", failure == null && cleanup.isSuccess && checks.length() == 6)
                        .put("fixtureRemoved", cleanup.isSuccess).put("checks", checks)
                    File(context.filesDir, "runtime-bridge-checks.json").writeText(report.toString(2))
                    running.set(false)
                }) { it.remove(game); marker.delete() }
            }
        }
        library.access<String>({ imported ->
            imported.fold(onSuccess = { id ->
                fixture = id
                checks.put("originalGameImported")
                val request = LaunchRequest(id, "nexus-smoke.exe")
                host.prepareRuntime(request) { prepared ->
                    if (prepared.isFailure) { finish(prepared.exceptionOrNull()); return@prepareRuntime }
                    checks.put("typedPrepareReady")
                    // A freshly prepared container has no evidence from this run.
                    File(RootFS.find(context).rootDir, "home/xuser/.wine/drive_c/nexus-evidence.txt").delete()
                    host.launchGame(request) { launched ->
                        if (launched.isFailure) { finish(launched.exceptionOrNull()); return@launchGame }
                        checks.put("typedLaunchRequested")
                        var blocked = false
                        library.access<Unit>({ blocked = (it.exceptionOrNull() as? FlutterError)?.code == "runtime_busy" }) { error("Leased library was accessible") }
                        if (!blocked) { finish(IllegalStateException("Library lease missing")); return@launchGame }
                        checks.put("libraryLockedWhileRunning")
                        Thread({
                            try {
                                val evidence = File(RootFS.find(context).rootDir, "home/xuser/.wine/drive_c/nexus-evidence.txt")
                                val deadline = android.os.SystemClock.elapsedRealtime() + 100_000
                                var text = ""
                                val expectedDirectory = File(context.noBackupFilesDir, "library-v1/games/$id/content").canonicalPath
                                val box64 = File(context.applicationInfo.nativeLibraryDir, "libnexus_box64.so").canonicalPath
                                var workingDirectoryObserved = false
                                while (android.os.SystemClock.elapsedRealtime() < deadline) {
                                    if (!workingDirectoryObserved) {
                                        workingDirectoryObserved = File("/proc").listFiles()?.any { proc ->
                                            try {
                                                proc.name.all(Char::isDigit) &&
                                                    Os.stat(proc.path).st_uid == android.os.Process.myUid() &&
                                                    Os.readlink("${proc.path}/exe") == box64 &&
                                                    File(proc, "comm").readText().trim() == "nexus-smoke.exe" &&
                                                    Os.readlink("${proc.path}/cwd") == expectedDirectory
                                            } catch (_: Exception) { false }
                                        } == true
                                    }
                                    text = if (evidence.isFile) evidence.readText().take(16_384) else ""
                                    if (text.contains("PROCESS_EXIT_0") && host.getRuntimeStatus().state == RuntimeState.IDLE) break
                                    if (host.getRuntimeStatus().state == RuntimeState.FAILED) error(host.getRuntimeStatus().message)
                                    Thread.sleep(500)
                                }
                                val markers = listOf("GUEST_SUBPAGE_PROTECTION_PASSED", "WINDOW_CREATED", "FONT_SELECTED", "FRAME_PAINTED", "POINTER_INPUT_RECEIVED", "ESCAPE_RECEIVED", "CLEAN_SHUTDOWN", "PROCESS_EXIT_0")
                                check(markers.all { text.contains(it) } && !text.contains("TIMEOUT_NO_INPUT")) { "Windows smoke markers missing: $text" }
                                check(host.getRuntimeStatus().state == RuntimeState.IDLE) { "Runtime did not return to idle" }
                                check(workingDirectoryObserved) { "Windows game did not use its imported executable directory" }
                                val drive = File(RootFS.find(context).rootDir, "home/xuser/.wine/dosdevices/g:")
                                check(Os.readlink(drive.path) == expectedDirectory) { "Game drive G: was not mapped" }
                                report.put("guestWorkingDirectory", expectedDirectory)
                                checks.put("gameDirectoryAndDriveMapped")
                                report.put("guestEvidence", text)
                                checks.put("renderInputAndCleanExit")
                                main.post { finish() }
                            } catch (error: Exception) { main.post { finish(error) } }
                        }, "nexus-runtime-check").start()
                    }
                }
            }, onFailure = { finish(it) })
        }) { store ->
            if (marker.isFile) {
                val previous = JSONObject(marker.readText())
                val previousId = previous.getString("gameId")
                try {
                    val game = store.details(previousId).game
                    check(game.title == "Nexus runtime check ${previous.getString("checkId")}")
                    store.remove(previousId)
                } catch (missing: ImportRejected) { if (missing.code != "game_missing") throw missing }
                marker.delete()
            }
            val id = LibraryStore.newId()
            marker.writeText(JSONObject().put("gameId", id).put("checkId", checkId).toString())
            val stage = store.createStage(id)
            try {
                val copy = SafeCopy(File(stage, "content"), CopyControl())
                context.assets.open("nexus-smoke.exe").use { copy.file("nexus-smoke.exe", it) }
                store.publish(id, "Nexus runtime check $checkId", copy.finish()).id
            } catch (error: Exception) { store.discardStage(id); throw error }
        }
    }
}
