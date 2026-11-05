package com.example.bantay_baha

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PHONE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "dial911") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                try {
                    startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:911")))
                    result.success(true)
                } catch (_: ActivityNotFoundException) {
                    result.success(false)
                }
            }
    }

    private companion object {
        const val PHONE_CHANNEL = "bantay_baha/phone"
    }
}
