package com.pmusic.app

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.private.pmusic/platform"

    /**
     * On Android TV the IME (soft keyboard) is a floating overlay that temporarily
     * steals window focus.  Flutter's TextInput plugin responds to
     * onWindowFocusChanged(false) by calling hideSoftInputFromWindow(), which
     * creates a show/hide loop where the keyboard flickers and key presses have
     * no effect.
     *
     * Fix: when focus is lost while the IME is active, skip the super call
     * entirely so Flutter never receives the focus-lost event and leaves the
     * keyboard alone.  When focus is genuinely lost (e.g. switching apps) the
     * IME is not active, so super is called normally.
     */
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        if (hasFocus) {
            super.onWindowFocusChanged(true)
            return
        }
        val imm = getSystemService(android.view.inputmethod.InputMethodManager::class.java)
        if (imm != null && imm.isActive) {
            // IME overlay stole focus — do NOT notify Flutter or it will hide the keyboard.
            return
        }
        super.onWindowFocusChanged(false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTV" -> {
                        val uiModeManager =
                            getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                        val isTV =
                            uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
                        result.success(isTV)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

