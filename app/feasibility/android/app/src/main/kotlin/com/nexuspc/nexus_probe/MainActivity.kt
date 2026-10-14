package com.nexuspc.nexus_probe

import android.app.ActivityManager
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null &&
            applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0 &&
            intent.getBooleanExtra("surfaceProbe", false)) {
            startActivity(Intent(this, SurfaceProbeActivity::class.java))
        }
        if (savedInstanceState == null &&
            applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0 &&
            intent.getBooleanExtra("runtimeProbe", false)) {
            startActivity(Intent(this, RuntimeProbeActivity::class.java)
                .putExtra("autoInput", intent.getBooleanExtra("autoInput", false)))
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nexuspc/feasibility")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "profile" -> {
                        val memory = ActivityManager.MemoryInfo()
                        getSystemService(ActivityManager::class.java).getMemoryInfo(memory)
                        val vulkan = packageManager.systemAvailableFeatures
                            .firstOrNull { it.name == "android.hardware.vulkan.version" }?.version
                        result.success(mapOf(
                            "androidApi" to Build.VERSION.SDK_INT,
                            "manufacturer" to Build.MANUFACTURER,
                            "model" to Build.MODEL,
                            "hardware" to Build.HARDWARE,
                            "board" to Build.BOARD,
                            "socManufacturer" to Build.SOC_MANUFACTURER,
                            "socModel" to Build.SOC_MODEL,
                            "cpuAbis" to Build.SUPPORTED_ABIS.toList(),
                            "ramBytes" to memory.totalMem,
                            "availableRamBytes" to memory.availMem,
                            "vulkanFeatureVersion" to vulkan,
                            "runtimeValidated" to false
                        ))
                    }
                    "surface" -> {
                        startActivity(Intent(this, SurfaceProbeActivity::class.java))
                        result.success(null)
                    }
                    "runtime" -> {
                        startActivity(Intent(this, RuntimeProbeActivity::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
