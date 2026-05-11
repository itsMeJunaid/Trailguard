package com.trailguard.ai

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            LiteRtLmPlugin(this).register(flutterEngine.dartExecutor.binaryMessenger)
        } catch (t: Throwable) {
            Log.e("TrailGuard", "LiteRtLmPlugin register failed", t)
        }
    }
}
