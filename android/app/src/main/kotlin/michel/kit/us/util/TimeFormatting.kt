package michel.kit.us.util

import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

/**
 * Port of ios/LoverApp/Features/Time/TimeFormatting.swift +
 * UserProfileStore.swift's LocalDate / DisplayDate helpers. HK time zone
 * pinning matches iOS so anniversary cross-check produces the same ISO
 * string on both apps.
 */
object TimeFormatting {
    val weekdays = listOf("日", "一", "二", "三", "四", "五", "六")
    val monthsTC = listOf(
        "一月", "二月", "三月", "四月", "五月", "六月",
        "七月", "八月", "九月", "十月", "十一月", "十二月"
    )

    private val hkZone: ZoneId = ZoneId.of("Asia/Hong_Kong")
    private val isoFmt = DateTimeFormatter.ofPattern("yyyy-MM-dd")
    private val displayFmt = DateTimeFormatter.ofPattern("yyyy.MM.dd")

    fun todayISO(): String = LocalDate.now(hkZone).format(isoFmt)

    fun isoFromDate(d: LocalDate): String = d.format(isoFmt)

    fun parseISO(iso: String): LocalDate? = runCatching {
        LocalDate.parse(iso, isoFmt)
    }.getOrNull()

    /** "yyyy-MM-dd" → "M.d" */
    fun mdString(iso: String): String {
        val d = parseISO(iso) ?: return iso
        return "${d.monthValue}.${d.dayOfMonth}"
    }

    /** "yyyy-MM-dd" → "2026 · 五月 2 日 · 星期六" */
    fun fullString(iso: String): String {
        val d = parseISO(iso) ?: return iso
        val w = d.dayOfWeek.value % 7   // Mon=1..Sun=7 → Sun=0..Sat=6
        return "${d.year} · ${monthsTC[d.monthValue - 1]} ${d.dayOfMonth} 日 · 星期${weekdays[w]}"
    }

    fun weekday(iso: String): String {
        val d = parseISO(iso) ?: return ""
        val w = d.dayOfWeek.value % 7
        return weekdays[w]
    }

    /** Convert "yyyy-MM-dd" → "yyyy.MM.dd" for display. */
    fun displayFromISO(iso: String): String {
        val d = parseISO(iso) ?: return iso.replace("-", ".")
        return d.format(displayFmt)
    }

    fun daysBetween(startIso: String, endIso: String): Int {
        val a = parseISO(startIso) ?: return 0
        val b = parseISO(endIso) ?: return 0
        return ChronoUnit.DAYS.between(a, b).toInt()
    }

    /**
     * Mirrors iOS Anniversary.nextOccurrence — returns (next-occurrence ISO,
     * days from today, ordinal year-count or null for monthly).
     */
    data class Occurrence(val isoDate: String, val daysAway: Int, val ordinal: Int?)

    fun nextOccurrence(
        baseIso: String,
        recur: String,
        today: LocalDate = LocalDate.now(hkZone)
    ): Occurrence {
        val base = parseISO(baseIso) ?: today
        var next: LocalDate = when (recur) {
            "monthly" -> LocalDate.of(today.year, today.monthValue, base.dayOfMonth.coerceAtMost(28))
            else -> LocalDate.of(today.year, base.monthValue, base.dayOfMonth.coerceAtMost(28))
        }
        if (next.isBefore(today)) {
            next = when (recur) {
                "monthly" -> next.plusMonths(1)
                else -> next.plusYears(1)
            }
        }
        val days = ChronoUnit.DAYS.between(today, next).toInt()
        val ord = if (recur == "yearly") next.year - base.year else null
        return Occurrence(next.format(isoFmt), days, ord)
    }
}
