package com.nexuspc.app

import android.content.pm.ApplicationInfo
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent
import com.nexuspc.app.library.LibraryHost

class MainActivity : FlutterActivity() {
    private var host: NexusHost? = null
    private var library: LibraryHost? = null
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
        library = LibraryHost(this)
        NexusLibraryApi.setUp(messenger, library)
    }
    @Deprecated("Activity result callback required by the FlutterActivity picker integration")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (library?.onActivityResult(requestCode, resultCode, data) != true)
            super.onActivityResult(requestCode, resultCode, data)
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        NexusLibraryApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        library?.close()
        library = null
        NexusHostApi.setUp(flutterEngine.dartExecutor.binaryMessenger, null)
        host?.close()
        host = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
