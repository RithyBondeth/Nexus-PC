package com.nexuspc.nexus_probe

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.widget.TextView
import androidx.preference.PreferenceManager
import com.winlator.container.ContainerManager
import com.winlator.core.TarCompressorUtils
import com.winlator.xenvironment.RootFS
import com.winlator.xenvironment.RootFSInstaller
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executors

// One fixed, app-owned test executable; no user-supplied commands or directories.
class RuntimeProbeActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val status = TextView(this).apply { text = "Preparing pinned Wine / Box64 smoke runtime…" }
        setContentView(status)
        val worker = Executors.newSingleThreadExecutor()
        worker.execute {
            try {
                val root = RootFS.find(this)
                if (!root.isValid) {
                    root.rootDir.mkdirs()
                    check(TarCompressorUtils.extract(TarCompressorUtils.Type.ZSTD, this,
                        RootFSInstaller.FILENAME, root.rootDir)) { "Root filesystem extraction failed" }
                    root.createRFSVersionFile(RootFSInstaller.LATEST_VERSION.toInt())
                }
                val manager = ContainerManager(this)
                runOnUiThread {
                    val existing = manager.containers.firstOrNull { it.name == "Nexus smoke" }
                    if (existing != null) launch(existing.id, existing.rootDir)
                    else manager.createContainerAsync(JSONObject().apply {
                        put("name", "Nexus smoke")
                        put("screenSize", "800x600")
                        put("graphicsDriver", "vortek,gladio")
                        put("dxwrapper", "wined3d")
                        put("wincomponents", "direct3d=0,directsound=0,directmusic=0,directshow=0,directplay=0,xaudio=0,vcrun2005=0,vcrun2010=0,wmdecoder=0")
                        put("drives", "")
                        put("envVars", "BOX64_LOG=1 WINEDEBUG=+timestamp,+seh")
                    }) { container ->
                        if (container == null) status.text = "Container preparation failed"
                        else launch(container.id, container.rootDir)
                    }
                }
            } catch (error: Exception) {
                Log.e("NexusRuntime", "Runtime preparation failed", error)
                runOnUiThread { status.text = "Preparation failed: ${error.message}" }
            } finally { worker.shutdown() }
        }
    }

    private fun launch(id: Int, directory: File) {
        val drive = File(directory, ".wine/drive_c")
        val game = File(drive, "nexus-smoke.exe")
        assets.open("nexus-smoke.exe").use { input -> game.outputStream().use { input.copyTo(it) } }
        File(drive, "nexus-evidence.txt").takeIf { it.exists() }?.delete()
        PreferenceManager.getDefaultSharedPreferences(this).edit()
            .putString("box64_version", "0.4.4")
            .putInt("box64_logs", 1)
            .putBoolean("enable_wine_debug", true).apply()
        startActivity(Intent(this, RuntimeDisplayActivity::class.java)
            .putExtra("container_id", id)
            .putExtra("exec_path", game.path)
            .putExtra("nexus_smoke", true)
            .putExtra("autoInput", intent.getBooleanExtra("autoInput", false)))
        finish()
    }
}
