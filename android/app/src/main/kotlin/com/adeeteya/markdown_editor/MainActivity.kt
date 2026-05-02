package com.adeeteya.markdown_editor

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.xmlpull.v1.XmlPullParser
import org.xmlpull.v1.XmlPullParserFactory
import java.io.BufferedReader
import java.io.File
import java.io.FileInputStream
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.adeeteya.markdown_editor/channel"
    private var fileContentToSend: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return

        if (intent.action == Intent.ACTION_VIEW || intent.action == Intent.ACTION_EDIT) {
            val uri: Uri? = intent.data
            uri?.let {
                fileContentToSend = readTextFromUri(it)
            }
        }
    }

    private fun readTextFromUri(uri: Uri): String? {
        return try {
            contentResolver.openInputStream(uri)?.use { inputStream ->
                BufferedReader(InputStreamReader(inputStream)).use { reader ->
                    reader.readText()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getFileContent" -> {
                        result.success(fileContentToSend)
                        fileContentToSend = null // send only once
                    }
                    "clearFileContent" -> {
                        fileContentToSend = null
                        result.success(null)
                    }
                    "getSystemFontFamilies" -> {
                        result.success(getSystemFontFamilies())
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    private fun getSystemFontFamilies(): List<String> {
        val fontFamilies = linkedSetOf<String>()
        val fontConfigPaths = listOf(
            "/system/etc/fonts.xml",
            "/system/etc/system_fonts.xml",
            "/vendor/etc/fonts.xml",
            "/product/etc/fonts.xml"
        )

        for (path in fontConfigPaths) {
            val file = File(path)
            if (!file.exists()) {
                continue
            }
            FileInputStream(file).use { inputStream ->
                val parser = XmlPullParserFactory.newInstance().newPullParser()
                parser.setInput(inputStream, null)
                var eventType = parser.eventType
                while (eventType != XmlPullParser.END_DOCUMENT) {
                    if (eventType == XmlPullParser.START_TAG) {
                        when (parser.name) {
                            "family", "alias" -> {
                                parser.getAttributeValue(null, "name")
                                    ?.trim()
                                    ?.takeIf { it.isNotEmpty() }
                                    ?.let { fontFamilies.add(it) }
                            }
                        }
                    }
                    eventType = parser.next()
                }
            }
        }

        return fontFamilies.sortedWith(String.CASE_INSENSITIVE_ORDER)
    }
}

