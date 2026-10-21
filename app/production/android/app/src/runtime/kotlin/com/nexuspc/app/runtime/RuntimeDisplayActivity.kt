package com.nexuspc.app.runtime

import android.os.Build
import android.view.MenuItem
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
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
    private var backCallback: Any? = null
    @Suppress("DEPRECATION")
    private fun openRuntimeMenu() { super.onBackPressed() }
    override fun onNavigationItemSelected(item: MenuItem): Boolean {
        if (intent.getBooleanExtra("librarySession", false) &&
            resources.getResourceEntryName(item.itemId) == "menu_item_exit") {
            Session.update(com.nexuspc.app.RuntimeState.STOPPING, "runtime_stopping", "Stopping the Windows session…")
            finish()
            return true
        }
        return super.onNavigationItemSelected(item)
    }
    private var injected = false
    private var attempts = 0
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 33) {
            val callback = OnBackInvokedCallback { openRuntimeMenu() }
            backCallback = callback
            onBackInvokedDispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT, callback)
        }
        ProcessHelper.addDebugCallback(logger)
        if (intent.getBooleanExtra("librarySession", false)) Session.display = java.lang.ref.WeakReference(this)
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
        if (Build.VERSION.SDK_INT >= 33) (backCallback as? OnBackInvokedCallback)?.let { onBackInvokedDispatcher.unregisterOnBackInvokedCallback(it) }
        handler.removeCallbacksAndMessages(null)
        ProcessHelper.removeDebugCallback(logger)
        super.onDestroy()
        if (intent.getBooleanExtra("librarySession", false)) {
            Session.display.clear()
            val exit = intent.getIntExtra("nexus_exit_code", -1)
            if (Session.state.state != com.nexuspc.app.RuntimeState.STOPPING && exit != 0) {
                Session.update(com.nexuspc.app.RuntimeState.FAILED, "guest_failed", "Windows process ended with code $exit. Check runtime diagnostics.")
            }
            Session.drain(applicationContext)
        }
    }
}
