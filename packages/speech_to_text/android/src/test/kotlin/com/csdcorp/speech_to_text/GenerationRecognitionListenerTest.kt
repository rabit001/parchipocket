package com.csdcorp.speech_to_text

import android.os.Bundle
import org.junit.Assert.assertEquals
import org.junit.Test

class GenerationRecognitionListenerTest {
    private data class Event(val generation: Long, val type: String, val payload: String?)

    private fun listener(
        generation: Long,
        router: RecognitionGenerationRouter,
    ) = GenerationRecognitionListener(
        generationId = generation,
        onPartial = { id, _ -> router.partial(id, "partial") },
        onFinal = { id, _ -> router.result(id, "final") },
        onReady = { id -> router.status(id, "listening") },
        onBeginning = {},
        onEnd = { id -> router.status(id, "notListening") },
        onError = { id, code -> router.error(id, "error:$code") },
        onRms = { _, _ -> },
    )

    @Test
    fun listenersKeepTheirOwnGenerationAndOldCallbacksAreIgnored() {
        val events = mutableListOf<Event>()
        val router = RecognitionGenerationRouter { id, type, payload ->
            events += Event(id, type, payload)
        }
        val generationA = router.begin()
        val listenerA = listener(generationA, router)
        router.terminal(generationA)
        val generationB = router.begin()
        val listenerB = listener(generationB, router)
        events.clear()

        listenerA.onReadyForSpeech(null)
        listenerA.onResults(Bundle())
        listenerB.onReadyForSpeech(null)

        assertEquals(listOf(Event(generationB, "status", "listening")), events)
        assertEquals(generationA, listenerA.generationId)
        assertEquals(generationB, listenerB.generationId)
    }

    @Test
    fun finalResultIsEmittedBeforeTerminalCompletion() {
        val events = mutableListOf<String>()
        val router = RecognitionGenerationRouter { _, type, _ -> events += type }
        val listener = listener(router.begin(), router)
        events.clear()

        listener.onResults(Bundle())

        assertEquals(listOf("result", "terminal"), events)
    }

    @Test
    fun errorPrecedesTerminalAndDuplicateTerminalIsSuppressed() {
        val events = mutableListOf<String>()
        val router = RecognitionGenerationRouter { _, type, _ -> events += type }
        val generation = router.begin()
        val listener = listener(generation, router)
        events.clear()

        listener.onError(7)
        listener.onResults(Bundle())
        router.terminal(generation)

        assertEquals(listOf("error", "terminal"), events)
    }

    @Test
    fun notListeningOnlyChangesRecordingStatus() {
        val events = mutableListOf<String>()
        val router = RecognitionGenerationRouter { _, type, _ -> events += type }
        val generation = router.begin()
        val listener = listener(generation, router)
        events.clear()

        listener.onEndOfSpeech()

        assertEquals(listOf("status"), events)
        assertEquals(true, router.isActive(generation))
    }
}
