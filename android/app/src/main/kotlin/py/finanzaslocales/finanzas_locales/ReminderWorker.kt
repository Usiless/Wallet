package py.finanzaslocales.finanzas_locales

import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException

/** Serial storage work; the caller supplies the platform-thread result dispatcher. */
internal class ReminderWorker(private val dispatchResult: (() -> Unit) -> Unit) : AutoCloseable {
    private val executor = Executors.newSingleThreadExecutor { task ->
        Thread(task, "cabal-payment-reminders")
    }

    fun execute(operation: () -> Any?, reply: (Result<Any?>) -> Unit) {
        try {
            executor.execute {
                val result = runCatching(operation)
                dispatchResult { reply(result) }
            }
        } catch (error: RejectedExecutionException) {
            dispatchResult { reply(Result.failure(error)) }
        }
    }

    // Drain accepted work without blocking the UI during engine cleanup.
    override fun close() { executor.shutdown() }
}
