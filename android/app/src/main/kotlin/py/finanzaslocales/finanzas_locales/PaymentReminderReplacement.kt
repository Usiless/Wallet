package py.finanzaslocales.finanzas_locales

/** Identity includes obligation revision so financial edits also invalidate an old notice. */
internal data class PaymentReminderEntry(val id: String, val signature: List<String>, val generation: String, val at: Long)
internal data class PaymentReminderReplacement(val entries: List<PaymentReminderEntry>, val invalidated: List<PaymentReminderEntry>, val delivered: Set<String>)

internal fun replacePaymentReminderEntries(
    old: List<PaymentReminderEntry>,
    incoming: List<PaymentReminderEntry>,
    delivered: Set<String>,
    now: Long,
    generation: String,
): PaymentReminderReplacement {
    val previous = old.associateBy { it.id }
    val current = incoming.associateBy { it.id }
    val unchanged = incoming.filter { previous[it.id]?.signature == it.signature }.map { it.id }.toSet()
    return PaymentReminderReplacement(
        incoming.map { it.copy(generation = if (it.id in unchanged) previous.getValue(it.id).generation else generation) },
        old.filter { current[it.id]?.signature != it.signature },
        delivered.intersect(current.keys) + incoming.filter { it.id !in unchanged && it.at <= now }.map { it.id },
    )
}
