package com.nexuspc.app

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import java.io.File
import java.util.ArrayDeque
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class NexusHost(private val context: Context, messenger: BinaryMessenger) : NexusHostApi {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val events = NexusEventApi(messenger)
    private val logs = ArrayDeque<RuntimeLog>()
    @Volatile private var closed = false
    private val unavailable = RuntimeStatus(RuntimeState.UNAVAILABLE, "runtime_unavailable",
        "Game runtime is not integrated yet.", System.currentTimeMillis())

    private fun <T> background(callback: (Result<T>) -> Unit, operation: () -> T) {
        worker.execute {
            val result = try { Result.success(operation()) }
            catch (error: Exception) {
                Result.failure<T>(if (error is FlutterError) error else
                    FlutterError("native_error", error.message ?: "Native operation failed"))
            }
            catch (error: LinkageError) {
                Result.failure<T>(FlutterError("native_library_unavailable", error.message))
            }
            main.post { if (!closed) callback(result) }
        }
    }
    private fun record(level: LogLevel, code: String, message: String) {
        val entry = RuntimeLog(System.currentTimeMillis(), level, code, message)
        synchronized(logs) {
            if (logs.size == 128) logs.removeFirst()
            logs.addLast(entry)
        }
        Log.i("NexusFoundation", "$code: $message")
        main.post { if (!closed) events.onRuntimeLog(entry) { } }
    }
    override fun getDeviceProfile(callback: (Result<DeviceProfile>) -> Unit) = background(callback) {
        val memory = ActivityManager.MemoryInfo()
        context.getSystemService(ActivityManager::class.java).getMemoryInfo(memory)
        val gpu = NativeCore.gpuInfo()
        record(LogLevel.INFO, "device_profile", "Android ${Build.VERSION.SDK_INT}; ${Build.SOC_MODEL}")
        DeviceProfile(Build.VERSION.SDK_INT.toLong(), context.applicationInfo.targetSdkVersion.toLong(),
            Build.MODEL, Build.HARDWARE, Build.BOARD, Build.SOC_MODEL,
            Build.SUPPORTED_ABIS.toList(), memory.totalMem,
            gpu[0].takeIf { it.isNotEmpty() }, gpu[1].takeIf { it.isNotEmpty() })
    }
    override fun probePackagedExecution(callback: (Result<ExecutionProbeResult>) -> Unit) = background(callback) {
        val executable = File(context.applicationInfo.nativeLibraryDir, "libnexus_exec_probe.so")
        if (!executable.isFile || !executable.canExecute()) {
            record(LogLevel.ERROR, "execution_probe_missing", "Packaged executable is unavailable")
            return@background ExecutionProbeResult(false, "Packaged native executable is unavailable.")
        }
        val process = ProcessBuilder(executable.absolutePath).redirectErrorStream(true).start()
        try {
            if (!process.waitFor(3, TimeUnit.SECONDS)) {
                record(LogLevel.ERROR, "execution_probe_timeout", "Native helper timed out")
                return@background ExecutionProbeResult(false, "Native helper timed out.")
            }
            val output = process.inputStream.bufferedReader().use { reader ->
                buildString {
                    repeat(256) {
                        val character = reader.read()
                        if (character == -1) return@buildString
                        append(character.toChar())
                    }
                }
            }.trim()
            val exit = process.exitValue()
            val passed = exit == 0 && output == "NEXUS_EXEC_OK"
            val code = if (passed) "execution_probe_pass" else "execution_probe_failed"
            record(if (passed) LogLevel.INFO else LogLevel.ERROR, code, "Exit $exit; $output")
            ExecutionProbeResult(passed,
                if (passed) "Bundled native helper executed on target API 36. Windows runtime remains unavailable."
                else "Native helper failed (exit $exit).", exit.toLong(), executable.absolutePath)
        } finally {
            if (process.isAlive) process.destroyForcibly()
            process.inputStream.close()
            process.outputStream.close()
            process.errorStream.close()
        }
    }
    override fun getRuntimeStatus(): RuntimeStatus = unavailable
    private fun validate(request: LaunchRequest) {
        val path = request.executableRelativePath
        if (request.gameId.isBlank() || path.isBlank() || path.startsWith("/") ||
            path.contains('\\') || path.contains(':') || path.contains('\u0000') ||
            path.split('/').any { it == ".." || it.isEmpty() }) {
            throw FlutterError("invalid_argument", "Use a game ID and a relative executable path.")
        }
    }
    private fun reject(request: LaunchRequest, callback: (Result<RuntimeStatus>) -> Unit) = background(callback) {
        validate(request)
        record(LogLevel.WARNING, "runtime_unavailable", "Launch rejected: runtime is not integrated")
        main.post { if (!closed) events.onRuntimeStatus(unavailable) { } }
        throw FlutterError("runtime_unavailable", unavailable.message)
    }
    override fun prepareRuntime(request: LaunchRequest, callback: (Result<RuntimeStatus>) -> Unit) = reject(request, callback)
    override fun launchGame(request: LaunchRequest, callback: (Result<RuntimeStatus>) -> Unit) = reject(request, callback)
    override fun stopGame(callback: (Result<RuntimeStatus>) -> Unit) = background(callback) { unavailable }
    override fun getRecentLogs(limit: Long): List<RuntimeLog> {
        if (limit !in 1L..128L) throw FlutterError("invalid_argument", "Log limit must be 1 through 128.")
        return synchronized(logs) { logs.toList().takeLast(limit.toInt()) }
    }
    fun close() {
        closed = true
        worker.shutdownNow()
    }
}
