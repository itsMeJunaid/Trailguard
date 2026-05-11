package com.trailguard.ai

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.google.ai.edge.litertlm.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.onCompletion
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream

class LiteRtLmPlugin(private val context: Context) {

    private var engine: Engine? = null
    private var conversation: Conversation? = null
    private var lastSystemPrompt: String? = null
    private var eventSink: EventChannel.EventSink? = null

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val main = Handler(Looper.getMainLooper())
    private var currentJob: Job? = null

    private var totalTokens: Long = 0
    private var sessionTokens: Long = 0

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "loadModel" -> loadModel(call, result)
                    "sendMessage" -> sendTextMessage(call, result)
                    "sendMessageWithImage" -> sendImageMessage(call, result)
                    "cancel" -> { currentJob?.cancel(); result.success(null) }
                    "unload" -> unload(result)
                    "isLoaded" -> result.success(engine != null)
                    "getStats" -> result.success(mapOf(
                        "totalTokens" to totalTokens,
                        "sessionTokens" to sessionTokens
                    ))
                    else -> result.notImplemented()
                }
            } catch (t: Throwable) {
                Log.e(TAG, "dispatch", t)
                result.error("ERR", t.message, null)
            }
        }

        EventChannel(messenger, STREAM).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(a: Any?, s: EventChannel.EventSink?) { eventSink = s }
                override fun onCancel(a: Any?) { eventSink = null }
            }
        )
    }

    // ── loadModel ────────────────────────────────────────────────────

    private fun loadModel(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
            ?: return result.error("NO_PATH", "path required", null)
        val gpu = call.argument<Boolean>("useGpu") ?: false

        scope.launch {
            try {
                closeAll()

                // CRITICAL: set visionBackend for multimodal image support.
                // CPU is recommended for vision stability on all chipsets.
                val cfg = EngineConfig(
                    modelPath = path,
                    backend = if (gpu) Backend.GPU() else Backend.CPU(),
                    visionBackend = Backend.CPU(),
                    cacheDir = context.cacheDir.absolutePath,
                )
                Log.i(TAG, "Engine.initialize() path=$path gpu=$gpu visionBackend=CPU")
                val eng = Engine(cfg)
                eng.initialize()
                engine = eng
                sessionTokens = 0
                Log.i(TAG, "Engine ready")
                main.post { result.success(true) }
            } catch (t: Throwable) {
                Log.e(TAG, "loadModel", t)
                main.post { result.error("LOAD_FAIL", t.message, null) }
            }
        }
    }

    // ── Text-only ────────────────────────────────────────────────────

    private fun sendTextMessage(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text")
            ?: return result.error("NO_TEXT", "text required", null)
        val system = call.argument<String>("systemPrompt")
        val eng = engine ?: return result.error("NOT_LOADED", "load model first", null)

        currentJob?.cancel()
        currentJob = scope.launch {
            try {
                ensureConversation(eng, system)
                streamFlow(conversation!!.sendMessageAsync(text), result)
            } catch (t: Throwable) {
                streamError(t, result)
            }
        }
    }

    // ── Text + Image (multimodal) ────────────────────────────────────

    private fun sendImageMessage(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text") ?: "Describe this image."
        val imagePath = call.argument<String>("imagePath")
        val system = call.argument<String>("systemPrompt")
        val eng = engine ?: return result.error("NOT_LOADED", "load model first", null)

        if (imagePath.isNullOrBlank()) {
            return result.error("NO_IMAGE", "imagePath required", null)
        }

        currentJob?.cancel()
        currentJob = scope.launch {
            try {
                ensureConversation(eng, system)

                // Downscale to 896px max → temp JPEG file.
                // Gemma 4 has a 2520-patch limit; large images cause SIGSEGV.
                val safeFile = optimizeImageToTempFile(File(imagePath))

                Log.i(TAG, "Sending multimodal: ${safeFile.length()} bytes img + text(${text.length})")

                // Use Content.ImageFile with the safe temp path — avoids
                // passing large byte arrays through JNI.
                val contents = Contents.of(
                    Content.ImageFile(safeFile.absolutePath),
                    Content.Text(text),
                )

                streamFlow(conversation!!.sendMessageAsync(contents), result)

            } catch (t: Throwable) {
                Log.e(TAG, "sendImageMessage", t)
                streamError(t, result)
            }
        }
    }

    // ── Shared streaming ─────────────────────────────────────────────

    private suspend fun streamFlow(
        flow: kotlinx.coroutines.flow.Flow<Message>,
        result: MethodChannel.Result
    ) {
        var tokenCount = 0
        val startMs = System.currentTimeMillis()

        flow
            .catch { err ->
                Log.e(TAG, "stream error", err)
                emitToFlutter(mapOf("error" to (err.message ?: "stream error")))
            }
            .onCompletion {
                val elapsed = System.currentTimeMillis() - startMs
                totalTokens += tokenCount
                sessionTokens += tokenCount
                emitToFlutter(mapOf("done" to true, "tokens" to tokenCount, "elapsedMs" to elapsed))
            }
            .collect { msg ->
                tokenCount++
                val token = msg.toString()
                if (token.isNotEmpty()) emitToFlutter(mapOf("token" to token))
            }

        main.post { result.success(null) }
    }

    private fun emitToFlutter(data: Map<String, Any?>) {
        main.post {
            try { eventSink?.success(data) } catch (_: Throwable) {}
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────

    private fun ensureConversation(eng: Engine, system: String?) {
        if (conversation == null || system != lastSystemPrompt) {
            try { conversation?.close() } catch (_: Throwable) {}
            val ccfg = if (!system.isNullOrBlank()) {
                ConversationConfig(
                    systemInstruction = Contents.of(system),
                    samplerConfig = SamplerConfig(topK = 40, topP = 0.95, temperature = 0.7),
                )
            } else {
                ConversationConfig(
                    samplerConfig = SamplerConfig(topK = 40, topP = 0.95, temperature = 0.7),
                )
            }
            conversation = eng.createConversation(ccfg)
            lastSystemPrompt = system
        }
    }

    /// Downscale image to max 896px longest side, save as temp JPEG.
    /// This avoids Gemma 4's 2520-patch SIGSEGV crash on large images.
    private fun optimizeImageToTempFile(src: File): File {
        // Probe dimensions
        val probeOpts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(src.absolutePath, probeOpts)

        val maxSide = 896
        val origMax = maxOf(probeOpts.outWidth, probeOpts.outHeight)

        // Coarse downsample via inSampleSize (fast, memory efficient)
        val sampleSize = if (origMax > maxSide) {
            (origMax.toFloat() / maxSide).toInt().coerceAtLeast(1)
        } else 1

        val decodeOpts = BitmapFactory.Options().apply { inSampleSize = sampleSize }
        var bmp = BitmapFactory.decodeFile(src.absolutePath, decodeOpts)
            ?: throw IllegalArgumentException("Cannot decode image: ${src.absolutePath}")

        // Fine scale if still over limit
        if (bmp.width > maxSide || bmp.height > maxSide) {
            val ratio = maxSide.toFloat() / maxOf(bmp.width, bmp.height)
            val newW = (bmp.width * ratio).toInt()
            val newH = (bmp.height * ratio).toInt()
            bmp = Bitmap.createScaledBitmap(bmp, newW, newH, true)
        }

        // Write to temp JPEG
        val temp = File(context.cacheDir, "trailguard_img_${System.currentTimeMillis()}.jpg")
        FileOutputStream(temp).use { out ->
            bmp.compress(Bitmap.CompressFormat.JPEG, 85, out)
        }

        Log.i(TAG, "Image optimized: ${probeOpts.outWidth}x${probeOpts.outHeight} → " +
                "${bmp.width}x${bmp.height} (${temp.length()} bytes)")
        return temp
    }

    private fun streamError(t: Throwable, result: MethodChannel.Result) {
        Log.e(TAG, "send failed", t)
        emitToFlutter(mapOf("error" to (t.message ?: "error")))
        main.post { result.error("STREAM_ERR", t.message, null) }
    }

    private fun closeAll() {
        try { currentJob?.cancel() } catch (_: Throwable) {}
        try { conversation?.close() } catch (_: Throwable) {}
        try { engine?.close() } catch (_: Throwable) {}
        conversation = null
        engine = null
        lastSystemPrompt = null
    }

    private fun unload(result: MethodChannel.Result) {
        scope.launch {
            closeAll()
            main.post { result.success(null) }
        }
    }

    companion object {
        const val CHANNEL = "com.trailguard.ai/litertlm"
        const val STREAM = "com.trailguard.ai/litertlm/stream"
        private const val TAG = "TrailGuardLiteRt"
    }
}
