package com.csdcorp.speech_to_text

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class RecognitionGenerationRouterTest {
    @Test fun generationsAreMonotonicAndDistinct() {
        val router = RecognitionGenerationRouter { _, _, _ -> }
        val first = router.begin()
        router.terminal(first)
        val second = router.begin()
        assertNotEquals(first, second)
    }

    @Test fun retiredCallbacksAreIgnored() {
        val events = mutableListOf<Triple<Long, String, String?>>()
        val router = RecognitionGenerationRouter { id, type, payload -> events += Triple(id, type, payload) }
        val first = router.begin()
        router.terminal(first)
        val second = router.begin()
        events.clear()
        router.result(first, "stale")
        router.status(second, "listening")
        assertEquals(listOf(Triple(second, "status", "listening")), events)
    }

    @Test fun resultPrecedesTerminalAndEmptyResultTerminates() {
        val events = mutableListOf<String>()
        val router = RecognitionGenerationRouter { _, type, _ -> events += type }
        val first = router.begin()
        events.clear()
        router.result(first, "final")
        assertEquals(listOf("result", "terminal"), events)
        val second = router.begin()
        events.clear()
        router.result(second, null)
        assertEquals(listOf("terminal"), events)
    }

    @Test fun errorPrecedesSingleTerminal() {
        val events = mutableListOf<String>()
        val router = RecognitionGenerationRouter { _, type, _ -> events += type }
        val generation = router.begin()
        events.clear()
        router.error(generation, "error_network")
        router.terminal(generation)
        assertEquals(listOf("error", "terminal"), events)
    }

    @Test fun notListeningIsNotTerminal() {
        val events = mutableListOf<String>()
        val router = RecognitionGenerationRouter { _, type, _ -> events += type }
        val generation = router.begin()
        events.clear()
        router.status(generation, "notListening")
        assertEquals(listOf("status"), events)
        assertEquals(true, router.isActive(generation))
    }
}
