package com.csdcorp.speech_to_text

import android.os.Bundle
import android.speech.RecognitionListener

/** One Android listener instance permanently bound to one recognition generation. */
internal class GenerationRecognitionListener(
    val generationId: Long,
    private val onPartial: (Long, Bundle?) -> Unit,
    private val onFinal: (Long, Bundle?) -> Unit,
    private val onReady: (Long) -> Unit,
    private val onBeginning: (Long) -> Unit,
    private val onEnd: (Long) -> Unit,
    private val onError: (Long, Int) -> Unit,
    private val onRms: (Long, Float) -> Unit,
) : RecognitionListener {
    override fun onPartialResults(results: Bundle?) = onPartial(generationId, results)
    override fun onResults(results: Bundle?) = onFinal(generationId, results)
    override fun onReadyForSpeech(params: Bundle?) = onReady(generationId)
    override fun onBeginningOfSpeech() = onBeginning(generationId)
    override fun onEndOfSpeech() = onEnd(generationId)
    override fun onError(error: Int) = onError(generationId, error)
    override fun onRmsChanged(rmsdB: Float) = onRms(generationId, rmsdB)
    override fun onBufferReceived(buffer: ByteArray?) {}
    override fun onEvent(eventType: Int, params: Bundle?) {}
}
