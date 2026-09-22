package com.steaunk.numi_app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

class MainActivity : FlutterFragmentActivity() {
    private var shares: MethodChannel? = null
    private val store get() = getSharedPreferences("travel_shares", MODE_PRIVATE)
    private fun pending() = try { JSONArray(store.getString("pending", "[]")) } catch (_: Exception) { JSONArray() }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shares = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "numi/travel_share")
        shares!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "peek" -> {
                    val first = pending().optJSONObject(0)
                    result.success(first?.let { mapOf("id" to it.getString("id"), "text" to it.getString("text")) })
                }
                "acknowledge" -> {
                    val rows = pending()
                    val kept = JSONArray()
                    for (i in 0 until rows.length()) {
                        val row = rows.getJSONObject(i)
                        if (row.getString("id") != call.arguments) kept.put(row)
                    }
                    store.edit().putString("pending", kept.toString()).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null) receive(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receive(intent)
    }

    private fun receive(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND || intent.type !in listOf("text/plain", "text/html")) return
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString().orEmpty()
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT).orEmpty()
        val combined = (if (subject.isNotBlank() && !text.contains(subject)) "$subject\n$text" else text).take(10000)
        if (combined.isBlank()) return
        val rows = pending()
        rows.put(JSONObject().put("id", UUID.randomUUID().toString()).put("text", combined))
        store.edit().putString("pending", rows.toString()).apply()
        // Consumed intent must not be imported again after activity recreation.
        intent.action = Intent.ACTION_MAIN
        intent.removeExtra(Intent.EXTRA_TEXT)
        intent.removeExtra(Intent.EXTRA_SUBJECT)
        shares?.invokeMethod("received", null)
    }
}
