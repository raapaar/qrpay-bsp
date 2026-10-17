package pg.qrpay.qrpay_bsp

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pg.qrpay/bsp")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openMerchantMenu" -> {
                        // Fixed public short code only. Never accept commands,
                        // merchant information or credentials from a QR payload.
                        val intent = Intent(Intent.ACTION_DIAL,
                            Uri.fromParts("tel", "*131*6#", null))
                        try {
                            startActivity(intent)
                            // Handoff is not submission or proof of payment.
                            result.success(null)
                        } catch (_: ActivityNotFoundException) {
                            result.error("NO_DIALLER", "No phone app is available.", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
