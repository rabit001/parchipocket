package com.csdcorp.speech_to_text

/** Serializes callbacks and suppresses events from retired native recognizers. */
internal class RecognitionGenerationRouter(
    private val emit: (Long, String, String?) -> Unit,
) {
    private var nextGeneration = 0L
    private var activeGeneration: Long? = null

    @Synchronized
    fun begin(): Long {
        check(activeGeneration == null) { "A recognition generation is still active" }
        return (++nextGeneration).also {
            activeGeneration = it
            emit(it, "session", null)
        }
    }

    @Synchronized
    fun isActive(generation: Long): Boolean = activeGeneration == generation

    @Synchronized
    fun currentGeneration(): Long? = activeGeneration

    @Synchronized
    fun status(generation: Long, status: String) {
        if (isActive(generation)) emit(generation, "status", status)
    }

    @Synchronized
    fun result(generation: Long, payload: String?) {
        if (!isActive(generation)) return
        if (payload != null) emit(generation, "result", payload)
        terminal(generation)
    }

    @Synchronized
    fun partial(generation: Long, payload: String) {
        if (isActive(generation)) emit(generation, "result", payload)
    }

    @Synchronized
    fun error(generation: Long, payload: String) {
        if (!isActive(generation)) return
        emit(generation, "error", payload)
        terminal(generation)
    }

    @Synchronized
    fun terminal(generation: Long) {
        if (!isActive(generation)) return
        emit(generation, "terminal", null)
        activeGeneration = null
    }
}
