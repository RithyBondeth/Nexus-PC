package com.nexuspc.app

object NativeCore {
    init { System.loadLibrary("nexus_core") }
    external fun gpuInfo(): Array<String>
}
