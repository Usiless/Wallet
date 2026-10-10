package py.finanzaslocales.finanzas_locales

import org.junit.Assert.*
import org.junit.Test

class PaymentReminderReplacementTest {
    private fun entry(id: String, generation: String = "old", signature: String = "unchanged", at: Long = 10) =
        PaymentReminderEntry(id, listOf(id, signature), generation, at)

    @Test fun unchangedNoticeKeepsActionAndDeliveryWhileUnrelatedObligationIsRemoved() {
        val result = replacePaymentReminderEntries(listOf(entry("a"), entry("b")), listOf(entry("a")), setOf("a", "b"), 20, "new")
        assertEquals("old", result.entries.single().generation)
        assertEquals(listOf("b"), result.invalidated.map { it.id })
        assertEquals(setOf("a"), result.delivered)
    }

    @Test fun editRejectsOldActionAndDoesNotRedeliverHistoricalReminder() {
        val result = replacePaymentReminderEntries(listOf(entry("a")), listOf(entry("a", signature = "edited")), setOf("a"), 20, "new")
        assertEquals("new", result.entries.single().generation)
        assertEquals(listOf("a"), result.invalidated.map { it.id })
        assertEquals(setOf("a"), result.delivered)
    }

    @Test fun newHistoricalRequestsAreSkippedButKnownDelayedAlarmRemainsDeliverable() {
        val result = replacePaymentReminderEntries(listOf(entry("delayed")), listOf(entry("historical"), entry("delayed"), entry("future", at = 30)), emptySet(), 20, "new")
        assertEquals(setOf("historical"), result.delivered)
        assertEquals("old", result.entries.first { it.id == "delayed" }.generation)
        assertEquals("new", result.entries.first { it.id == "future" }.generation)
    }

    @Test fun paidCancelledDisabledOrRemovedOnRestoreInvalidatesAllOldActions() {
        val result = replacePaymentReminderEntries(listOf(entry("a")), emptyList(), setOf("a"), 20, "new")
        assertTrue(result.entries.isEmpty())
        assertEquals(listOf("a"), result.invalidated.map { it.id })
        assertTrue(result.delivered.isEmpty())
    }
}
