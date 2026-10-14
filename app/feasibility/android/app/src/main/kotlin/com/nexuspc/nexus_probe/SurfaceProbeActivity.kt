package com.nexuspc.nexus_probe

import android.app.Activity
import android.os.Bundle
import android.view.Surface
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.widget.LinearLayout
import android.widget.TextView

class SurfaceProbeActivity : Activity(), SurfaceHolder.Callback {
    companion object { init { System.loadLibrary("nexus_probe") } }
    private external fun probeSurface(surface: Surface): String
    private lateinit var status: TextView
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        status = TextView(this).apply {
            text = "Waiting for native surface. This probe does not render frames."
            setTextIsSelectable(true)
        }
        val view = SurfaceView(this)
        view.holder.addCallback(this)
        setContentView(LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            addView(status)
            addView(view, LinearLayout.LayoutParams(-1, 0, 1f))
        })
    }
    override fun surfaceCreated(holder: SurfaceHolder) { status.text = probeSurface(holder.surface) }
    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}
    override fun surfaceDestroyed(holder: SurfaceHolder) {}
}
