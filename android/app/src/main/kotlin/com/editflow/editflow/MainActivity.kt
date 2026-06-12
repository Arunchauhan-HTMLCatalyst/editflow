package com.editflow.editflow

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Required for OAuth deep links in release builds.
    // Without this, app_links (used by supabase_flutter) never receives
    // the redirect URL when the app is resumed from an external browser.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
}
