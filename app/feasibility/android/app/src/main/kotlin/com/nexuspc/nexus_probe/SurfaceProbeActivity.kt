package com.nexuspc.nexus_probe

import android.app.Activity
import android.os.Bundle
import android.util.Log
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.WindowInsets
import android.widget.LinearLayout
import android.widget.TextView

class SurfaceProbeActivity : Activity(), SurfaceHolder.Callback {
    companion object { init { System.loadLibrary("nexus_probe") } }
    private external fun probeSurface(surface: Surface): String
    private lateinit var status: TextView
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        status = TextView(this).apply {
            text = "Waiting for Vulkan frame presentation."
            textSize = 12f
            setTextIsSelectable(true)
        }
        val view = SurfaceView(this)
        view.holder.addCallback(this)
        setContentView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setOnApplyWindowInsetsListener { root, insets ->
                val bars = insets.getInsets(WindowInsets.Type.systemBars())
                root.setPadding(bars.left, bars.top, bars.right, bars.bottom)
                insets
            }
            addView(status)
            addView(view, LinearLayout.LayoutParams(-1, 0, 1f))
        })
    }
    override fun surfaceCreated(holder: SurfaceHolder) {}
    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
        if (width > 0 && height > 0) {
            val report = probeSurface(holder.surface)
            status.text = report
            Log.i("NexusProbe", report)
        }
    }
    override fun surfaceDestroyed(holder: SurfaceHolder) {}
}
