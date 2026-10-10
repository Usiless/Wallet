package py.finanzaslocales.finanzas_locales

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

class ReminderWorkerTest {
    @Test fun storageRunsOffCallerAndRepliesOnlyThroughResultDispatcher() {
        val replies = LinkedBlockingQueue<() -> Unit>()
        val caller = Thread.currentThread()
        val worker = ReminderWorker { replies.add(it) }
        try {
            var operationThread: Thread? = null
            var resultThread: Thread? = null
            var result: Any? = null
            worker.execute({ operationThread = Thread.currentThread(); "loaded" }) {
                resultThread = Thread.currentThread()
                result = it.getOrThrow()
            }
            val reply = replies.poll(5, TimeUnit.SECONDS)
            assertNotNull("background work must produce a reply", reply)
            assertNotSame("storage must not block the caller", caller, operationThread)
            assertNull("result must wait for the dispatcher", result)
            reply!!()
            assertSame(caller, resultThread)
            assertEquals("loaded", result)
        } finally { worker.close() }
    }

    @Test fun replacementAndConsumeStayInOrderAndFailureDoesNotStopQueue() {
        val replies = LinkedBlockingQueue<() -> Unit>()
        val worker = ReminderWorker { replies.add(it) }
        val firstEntered = CountDownLatch(1)
        val releaseFirst = CountDownLatch(1)
        val operations = LinkedBlockingQueue<String>()
        try {
            worker.execute({
                firstEntered.countDown()
                check(releaseFirst.await(5, TimeUnit.SECONDS))
                operations.add("replace")
                throw IllegalStateException("storage unavailable")
            }) { assertTrue(it.isFailure) }
            assertTrue(firstEntered.await(5, TimeUnit.SECONDS))
            worker.execute({ operations.add("consume"); "payment" }) {
                assertEquals("payment", it.getOrThrow())
            }
            assertTrue("consume must wait for replacement", operations.isEmpty())
            releaseFirst.countDown()
            assertEquals("replace", operations.poll(5, TimeUnit.SECONDS))
            assertEquals("consume", operations.poll(5, TimeUnit.SECONDS))
            repeat(2) { replies.poll(5, TimeUnit.SECONDS)!!.invoke() }
        } finally { releaseFirst.countDown(); worker.close() }
    }
}
