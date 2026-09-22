package com.steaunk.numi_app

import android.content.Intent
import android.os.Bundle
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File
import java.util.concurrent.Executors
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

class MainActivity : FlutterFragmentActivity() {
    private val documentReader = Executors.newSingleThreadExecutor()
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
                    result.success(first?.let { it.keys().asSequence().associateWith { key -> it.getString(key) } })
                }
                "acknowledge" -> {
                    val rows = pending()
                    val kept = JSONArray()
                    for (i in 0 until rows.length()) {
                        val row = rows.getJSONObject(i)
                        if (row.getString("id") != call.arguments) kept.put(row)
                        else if (row.optString("type") == "pdf") {
                            val file = File(filesDir, "travel-shares/${row.getString("id")}.pdf")
                            file.delete()
                        }
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

    private fun enqueue(row: JSONObject) {
        val rows = pending()
        if (rows.length() >= 20) {
            File(filesDir, "travel-shares/${row.getString("id")}.pdf").delete()
            android.widget.Toast.makeText(this, "Review pending shares before sharing more files.", android.widget.Toast.LENGTH_LONG).show()
            return
        }
        rows.put(row)
        store.edit().putString("pending", rows.toString()).apply()
        shares?.invokeMethod("received", null)
    }

    private fun receive(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "application/pdf") {
            val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM) ?: intent.clipData?.getItemAt(0)?.uri
            intent.action = Intent.ACTION_MAIN
            intent.removeExtra(Intent.EXTRA_STREAM)
            documentReader.execute {
                val id = UUID.randomUUID().toString()
                val row = JSONObject().put("id", id).put("type", "pdf")
                val file = File(filesDir, "travel-shares/$id.pdf")
                try {
                    require(uri != null && uri.scheme == "content")
                    var name = "Ticket.pdf"
                    contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst()) name = cursor.getString(0).take(180)
                    }
                    file.parentFile!!.mkdirs()
                    contentResolver.openInputStream(uri)!!.use { input ->
                        file.outputStream().use { output ->
                            val buffer = ByteArray(8192)
                            var total = 0
                            while (true) {
                                val count = input.read(buffer)
                                if (count < 0) break
                                total += count
                                require(total <= 10 * 1024 * 1024)
                                output.write(buffer, 0, count)
                            }
                        }
                    }
                    val header = ByteArray(5)
                    file.inputStream().use { require(it.read(header) == 5 && String(header, Charsets.US_ASCII) == "%PDF-") }
                    row.put("path", file.absolutePath).put("name", name)
                } catch (_: Exception) {
                    file.delete()
                    row.put("error", "Could not read the shared PDF. Choose a PDF up to 10 MB using Select PDF.")
                }
                runOnUiThread { enqueue(row) }
            }
            return
        }
        if (intent?.action != Intent.ACTION_SEND || intent.type !in listOf("text/plain", "text/html")) return
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString().orEmpty()
        val subject = intent.getStringExtra(Intent.EXTRA_SUBJECT).orEmpty()
        val combined = (if (subject.isNotBlank() && !text.contains(subject)) "$subject\n$text" else text).take(10000)
        if (combined.isBlank()) return
        enqueue(JSONObject().put("id", UUID.randomUUID().toString()).put("text", combined))
        // Consumed intent must not be imported again after activity recreation.
        intent.action = Intent.ACTION_MAIN
        intent.removeExtra(Intent.EXTRA_TEXT)
        intent.removeExtra(Intent.EXTRA_SUBJECT)
        shares?.invokeMethod("received", null)
    }
}
