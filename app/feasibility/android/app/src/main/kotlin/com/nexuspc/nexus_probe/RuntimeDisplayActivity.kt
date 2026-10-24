package com.nexuspc.nexus_probe

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.winlator.XServerDisplayActivity
import com.winlator.core.Callback
import com.winlator.core.ProcessHelper
import com.winlator.xserver.Pointer
import com.winlator.xserver.XKeycode
import java.io.File

class RuntimeDisplayActivity : XServerDisplayActivity() {
    private val handler = Handler(Looper.getMainLooper())
    private val logger = Callback<String> { line -> Log.i("NexusGuest", line) }
    private var injected = false
    private var attempts = 0
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ProcessHelper.addDebugCallback(logger)
        if (intent.getBooleanExtra("autoInput", false)) handler.postDelayed(::testInput, 1000)
    }
    private fun testInput() {
        if (isFinishing || isDestroyed) return
        val evidence = File(container.rootDir, ".wine/drive_c/nexus-evidence.txt")
        val text = if (evidence.exists()) evidence.readText() else ""
        if (!injected && text.contains("FRAME_PAINTED")) {
            injected = true
            // Send to the app-owned X server, never the Android system input service.
            handler.postDelayed({
                xServer.injectPointerMove(150, 150)
                xServer.injectPointerButtonPress(Pointer.Button.BUTTON_LEFT)
                xServer.injectPointerButtonRelease(Pointer.Button.BUTTON_LEFT)
                Log.i("NexusRuntime", "X server pointer test injected")
            }, 8000)
            handler.postDelayed({
                xServer.injectKeyPress(XKeycode.KEY_ESC)
                xServer.injectKeyRelease(XKeycode.KEY_ESC)
                Log.i("NexusRuntime", "X server ESC test injected")
            }, 12000)
        }
        if (++attempts < 90) handler.postDelayed(::testInput, 1000)
        else if (!injected) Log.e("NexusRuntime", "Windows frame not observed within 90 seconds")
    }
    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        ProcessHelper.removeDebugCallback(logger)
        super.onDestroy()
    }
}
