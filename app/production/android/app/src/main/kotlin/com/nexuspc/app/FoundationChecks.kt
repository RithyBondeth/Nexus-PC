package com.nexuspc.app

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.File

// Called only by a debug-build intent; verifies actual native APIs on the device.
object FoundationChecks {
    fun run(host: NexusHost, context: Context, checkId: String) {
        val report = JSONObject().put("checkId", checkId)
        fun finish(error: Throwable? = null) {
            if (error != null) report.put("error", error.message)
            val checks = listOf("deviceProfile", "modernTarget", "packagedExecution",
                "invalidPathRejected", "prepareUnavailable", "runtimeUnavailable", "stopUnavailable",
                "logLimitRejected", "boundedLogs")
            report.put("passed", error == null && checks.all { report.optBoolean(it) })
            File(context.filesDir, "foundation-checks.json").writeText(report.toString(2))
            Log.i("NexusFoundation", "CHECKS: $report")
        }
        fun checkStopAndLogs() {
            host.stopGame { stopped ->
                report.put("stopUnavailable", stopped.getOrNull()?.state == RuntimeState.UNAVAILABLE)
                try { host.getRecentLogs(0); report.put("logLimitRejected", false) }
                catch (failure: FlutterError) { report.put("logLimitRejected", failure.code == "invalid_argument") }
                report.put("boundedLogs", host.getRecentLogs(128).size in 1..128)
                finish()
            }
        }
        fun checkLaunch() {
            host.launchGame(LaunchRequest("test", "game.exe")) { launch ->
                report.put("runtimeUnavailable", (launch.exceptionOrNull() as? FlutterError)?.code == "runtime_unavailable" &&
                    host.getRuntimeStatus().state == RuntimeState.UNAVAILABLE)
                checkStopAndLogs()
            }
        }
        fun checkPrepare() {
            host.prepareRuntime(LaunchRequest("test", "game.exe")) { prepared ->
                report.put("prepareUnavailable", (prepared.exceptionOrNull() as? FlutterError)?.code == "runtime_unavailable")
                checkLaunch()
            }
        }
        fun checkInvalidPath() {
            host.prepareRuntime(LaunchRequest("test", "../escape.exe")) { invalid ->
                report.put("invalidPathRejected", (invalid.exceptionOrNull() as? FlutterError)?.code == "invalid_argument")
                checkPrepare()
            }
        }
        fun checkExecution() {
            host.probePackagedExecution { probeResult ->
                probeResult.fold(onFailure = { finish(it) }, onSuccess = { probe ->
                    report.put("packagedExecution", probe.passed).put("helperExitCode", probe.exitCode)
                    checkInvalidPath()
                })
            }
        }
        host.getDeviceProfile { profileResult ->
            profileResult.fold(onFailure = { finish(it) }, onSuccess = { profile ->
                report.put("deviceProfile", profile.androidApi >= 31 && profile.ramBytes > 0 &&
                    profile.cpuAbis.contains("arm64-v8a"))
                report.put("model", profile.model).put("socModel", profile.socModel)
                report.put("ramBytes", profile.ramBytes).put("cpuAbis", org.json.JSONArray(profile.cpuAbis))
                report.put("renderer", profile.renderer).put("vulkanVersion", profile.vulkanVersion)
                report.put("targetApi", profile.targetApi).put("modernTarget", profile.targetApi == 36L)
                checkExecution()
            })
        }
    }
}
