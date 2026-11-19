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

    @Test fun newlyStartedGenerationBecomesActive() {
        val router = RecognitionGenerationRouter { _, _, _ -> }
        val generation = router.begin()
        assertEquals(true, router.isActive(generation))
        assertEquals(generation, router.currentGeneration())
    }

    @Test(expected = IllegalStateException::class)
    fun beginWhileActiveThrowsException() {
        val router = RecognitionGenerationRouter { _, _, _ -> }
        router.begin()
        router.begin()
    }

    @Test fun cancellingActiveGenerationReleasesLockAndEmitsTerminal() {
        val events = mutableListOf<Triple<Long, String, String?>>()
        val router = RecognitionGenerationRouter { id, type, payload -> events += Triple(id, type, payload) }
        val generation = router.begin()
        events.clear()
        val cancelled = router.cancel(generation)
        assertEquals(true, cancelled)
        assertEquals(false, router.isActive(generation))
        assertEquals(null, router.currentGeneration())
        assertEquals(listOf(Triple(generation, "terminal", null)), events)
    }

    @Test fun newGenerationCanBeginImmediatelyAfterCancellation() {
        val router = RecognitionGenerationRouter { _, _, _ -> }
        val first = router.begin()
        router.cancel(first)
        val second = router.begin()
        assertNotEquals(first, second)
        assertEquals(true, router.isActive(second))
        assertEquals(second, router.currentGeneration())
    }

    @Test fun repeatedCancelOperationsAreIdempotent() {
        val events = mutableListOf<String>()
        val router = RecognitionGenerationRouter { _, type, _ -> events += type }
        val generation = router.begin()
        events.clear()
        assertEquals(true, router.cancel(generation))
        assertEquals(false, router.cancel(generation))
        assertEquals(false, router.cancel())
        assertEquals(listOf("terminal"), events)
        assertEquals(null, router.currentGeneration())
    }

    @Test fun cancellingWithNoActiveGenerationIsSafe() {
        val events = mutableListOf<String>()
        val router = RecognitionGenerationRouter { _, type, _ -> events += type }
        assertEquals(false, router.cancel())
        assertEquals(false, router.cancel(99L))
        assertEquals(emptyList<String>(), events)
    }

    @Test fun staleCallbacksFromCancelledGenerationDoNotAffectNewGeneration() {
        val events = mutableListOf<Triple<Long, String, String?>>()
        val router = RecognitionGenerationRouter { id, type, payload -> events += Triple(id, type, payload) }
        val genA = router.begin()
        router.cancel(genA)
        val genB = router.begin()
        events.clear()

        router.result(genA, "stale result")
        router.error(genA, "stale error")
        router.terminal(genA)
        router.status(genA, "notListening")
        router.partial(genA, "stale partial")

        assertEquals(emptyList<Triple<Long, String, String?>>(), events)
        assertEquals(true, router.isActive(genB))
        assertEquals(genB, router.currentGeneration())
    }

    @Test fun errorAndCancelRaceProducesSingleTerminal() {
        val events = mutableListOf<String>()
        val router = RecognitionGenerationRouter { _, type, _ -> events += type }
        val generation = router.begin()
        events.clear()

        router.error(generation, "error_speech_timeout")
        val cancelResult = router.cancel(generation)

        assertEquals(false, cancelResult)
        assertEquals(listOf("error", "terminal"), events)
        assertEquals(null, router.currentGeneration())
    }

    @Test fun disposalDuringRecognitionReleasesActiveGeneration() {
        val events = mutableListOf<String>()
        val router = RecognitionGenerationRouter { _, type, _ -> events += type }
        val generation = router.begin()
        events.clear()

        router.dispose()
        assertEquals(false, router.isActive(generation))
        assertEquals(null, router.currentGeneration())
        assertEquals(listOf("terminal"), events)

        // Idempotent repeated disposal
        router.dispose()
        assertEquals(listOf("terminal"), events)

        // Can start new generation after disposal
        val nextGen = router.begin()
        assertEquals(true, router.isActive(nextGen))
    }

    @Test fun repeatedListenCancelListenCycleSucceeds() {
        val router = RecognitionGenerationRouter { _, _, _ -> }
        for (i in 1..5) {
            val gen = router.begin()
            assertEquals(true, router.isActive(gen))
            assertEquals(gen, router.currentGeneration())
            assertEquals(true, router.cancel(gen))
            assertEquals(false, router.isActive(gen))
            assertEquals(null, router.currentGeneration())
        }
    }
}
