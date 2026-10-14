package com.nexuspc.app

import android.content.pm.ApplicationInfo
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var host: NexusHost? = null
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null && applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0 &&
            intent.getBooleanExtra("foundationChecks", false)) {
            host?.let { FoundationChecks.run(it, applicationContext,
                intent.getStringExtra("foundationCheckId") ?: "manual") }
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        host = NexusHost(applicationContext, messenger)
        NexusHostApi.setUp(messenger, host)
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        NexusHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        host?.close()
        host = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
