package com.duemate.duemate

import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) because local_auth's
// BiometricPrompt needs a FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "duemate/app_lock")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // App Lock on: keep balances out of the recent-apps thumbnail.
                    // Older Android versions rely on the in-app privacy cover.
                    "setHideInRecents" -> {
                        val hide = call.arguments as? Boolean ?: false
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            setRecentsScreenshotEnabled(!hide)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
