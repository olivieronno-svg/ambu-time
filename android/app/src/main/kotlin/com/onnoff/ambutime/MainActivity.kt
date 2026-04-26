package com.onnoff.ambutime

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Edge-to-edge requis par Android 15+ (target SDK 35+).
        // Equivalent de enableEdgeToEdge() mais sans dependance a activity-ktx.
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
}
