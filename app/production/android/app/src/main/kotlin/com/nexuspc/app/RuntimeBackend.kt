package com.nexuspc.app

/** Optional engine boundary. The ordinary APK has no Windows engine dependency. */
interface RuntimeBackend {
    var onStatus: ((RuntimeStatus) -> Unit)?
    fun status(): RuntimeStatus
    fun prepare(request: LaunchRequest, callback: (Result<RuntimeStatus>) -> Unit)
    fun launch(request: LaunchRequest, callback: (Result<RuntimeStatus>) -> Unit)
    fun stop(callback: (Result<RuntimeStatus>) -> Unit)
    fun close()
}
