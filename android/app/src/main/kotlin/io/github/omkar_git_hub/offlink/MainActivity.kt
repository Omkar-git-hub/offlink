package io.github.omkar_git_hub.offlink

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "io.github.omkar_git_hub.offlink/background_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    val title = call.argument<String>("title")
                    val message = call.argument<String>("message")
                    OfflinkForegroundService.start(this, title, message)
                    result.success(true)
                }
                "stopForegroundService" -> {
                    OfflinkForegroundService.stop(this)
                    result.success(true)
                }
                "isServiceRunning" -> {
                    result.success(OfflinkForegroundService.isRunning)
                }
                else -> result.notImplemented()
            }
        }
    }
}
