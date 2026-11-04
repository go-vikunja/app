package io.vikunja.app.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WidgetLayoutsTest {

    // --- density tiers ---

    @Test
    fun `short widgets render dense`() {
        val layout = WidgetLayouts.forSize(widthDp = 180, heightDp = 100)

        assertEquals(14, layout.taskFontSizeSp)
        assertEquals(4, layout.rowPaddingDp)
    }

    @Test
    fun `mid-height widgets render medium density`() {
        val layout = WidgetLayouts.forSize(widthDp = 180, heightDp = 180)

        assertEquals(16, layout.taskFontSizeSp)
        assertEquals(6, layout.rowPaddingDp)
    }

    @Test
    fun `tall widgets render comfortable density`() {
        val layout = WidgetLayouts.forSize(widthDp = 320, heightDp = 320)

        assertEquals(18, layout.taskFontSizeSp)
        assertEquals(8, layout.rowPaddingDp)
    }

    @Test
    fun `density never gets denser as the widget grows`() {
        var previous = WidgetLayouts.forSize(widthDp = 320, heightDp = 60)
        for (height in 70..700 step 10) {
            val layout = WidgetLayouts.forSize(widthDp = 320, heightDp = height)
            assertTrue(
                "font shrank at height $height",
                layout.taskFontSizeSp >= previous.taskFontSizeSp,
            )
            assertTrue(
                "row padding shrank at height $height",
                layout.rowPaddingDp >= previous.rowPaddingDp,
            )
            previous = layout
        }
    }

    // --- section labels ---

    @Test
    fun `compact layout drops section labels`() {
        val layout = WidgetLayouts.forSize(widthDp = 320, heightDp = 100)

        assertFalse(layout.showSectionLabels)
    }

    @Test
    fun `medium layouts drop section labels`() {
        assertFalse(WidgetLayouts.forSize(320, 180).showSectionLabels)
    }

    @Test
    fun `comfortable layouts show section labels`() {
        assertTrue(WidgetLayouts.forSize(320, 320).showSectionLabels)
    }

    // --- due dates ---

    @Test
    fun `narrow layouts hide due dates`() {
        assertFalse(WidgetLayouts.forSize(widthDp = 180, heightDp = 320).showDueDates)
    }

    @Test
    fun `wide layouts show due dates`() {
        assertTrue(WidgetLayouts.forSize(widthDp = 320, heightDp = 320).showDueDates)
    }

    @Test
    fun `due-date width boundary is 250dp`() {
        assertFalse(WidgetLayouts.forSize(249, 320).showDueDates)
        assertTrue(WidgetLayouts.forSize(250, 320).showDueDates)
    }

    // --- row capacity ---

    @Test
    fun `declared minimum size is header-only`() {
        // widget.xml declares minHeight 40dp: only the title bar fits.
        val layout = WidgetLayouts.forSize(widthDp = 200, heightDp = 40)

        assertEquals(0, layout.maxTaskRows)
        assertTrue(layout.isHeaderOnly)
    }

    @Test
    fun `height below one dense row is header-only`() {
        val layout = WidgetLayouts.forSize(widthDp = 180, heightDp = 89)

        assertEquals(0, layout.maxTaskRows)
        assertTrue(layout.isHeaderOnly)
    }

    @Test
    fun `smallest candidate fits exactly one dense row`() {
        val layout = WidgetLayouts.forSize(widthDp = 180, heightDp = 100, sectionCount = 2)

        assertEquals(1, layout.maxTaskRows)
    }

    @Test
    fun `capacity grows with height`() {
        val oneRow = WidgetLayouts.forSize(180, 100)
        val threeRows = WidgetLayouts.forSize(180, 180)
        val fiveRows = WidgetLayouts.forSize(320, 320)
        val eightRows = WidgetLayouts.forSize(320, 450)

        assertEquals(1, oneRow.maxTaskRows)
        assertEquals(3, threeRows.maxTaskRows)
        assertEquals(5, fiveRows.maxTaskRows)
        assertEquals(8, eightRows.maxTaskRows)
    }

    @Test
    fun `capacity is monotonic within each density tier`() {
        val tiers = listOf(90..129, 130..259, 260..600)
        for (tier in tiers) {
            var previous = WidgetLayouts.forSize(320, tier.first).maxTaskRows
            for (height in tier) {
                val rows = WidgetLayouts.forSize(320, height).maxTaskRows
                assertTrue(
                    "capacity shrank inside a tier at height $height",
                    rows >= previous,
                )
                previous = rows
            }
        }
    }

    @Test
    fun `growing a widget never makes it header-only`() {
        for (height in 41..700) {
            val taller = WidgetLayouts.forSize(320, height).maxTaskRows
            val shorter = WidgetLayouts.forSize(320, height - 1).maxTaskRows
            assertTrue(
                "height $height dropped to header-only above ${height - 1}",
                taller != 0 || shorter == 0,
            )
        }
    }

    @Test
    fun `sections without tasks free label space`() {
        val withLabels = WidgetLayouts.forSize(320, 320, sectionCount = 2)
        val withoutLabels = WidgetLayouts.forSize(320, 320, sectionCount = 0)

        assertEquals(5, withLabels.maxTaskRows)
        assertEquals(6, withoutLabels.maxTaskRows)
    }

    @Test
    fun `capacity never goes negative`() {
        for ((width, height) in listOf(0 to 0, 1 to 1, -10 to -10, 200 to 10)) {
            assertTrue(
                "negative capacity at ${width}x$height",
                WidgetLayouts.forSize(width, height).maxTaskRows >= 0,
            )
        }
    }

    @Test
    fun `tier boundaries switch at exact heights`() {
        assertEquals(14, WidgetLayouts.forSize(250, 129).taskFontSizeSp)
        assertEquals(16, WidgetLayouts.forSize(250, 130).taskFontSizeSp)
        assertEquals(16, WidgetLayouts.forSize(250, 259).taskFontSizeSp)
        assertEquals(18, WidgetLayouts.forSize(250, 260).taskFontSizeSp)
    }

    // --- responsive size candidates ---

    @Test
    fun `size candidates stay within glance limits`() {
        assertTrue(WidgetLayouts.sizeCandidates.isNotEmpty())
        assertTrue(
            "glance recommends at most 5 responsive sizes",
            WidgetLayouts.sizeCandidates.size <= 5,
        )
    }

    @Test
    fun `candidates exercise every tier and date mode`() {
        fun candidateLayout(width: Int, height: Int): WidgetLayout {
            val candidate = WidgetLayouts.sizeCandidates.first {
                it.width.value.toInt() == width && it.height.value.toInt() == height
            }
            return WidgetLayouts.forSize(
                candidate.width.value.toInt(),
                candidate.height.value.toInt(),
            )
        }

        // smallest: dense, labels off, due dates off
        val small = candidateLayout(width = 180, height = 100)
        assertEquals(14, small.taskFontSizeSp)
        assertFalse(small.showDueDates)

        // wide but short: dense with due dates
        val wideShort = candidateLayout(width = 320, height = 100)
        assertEquals(14, wideShort.taskFontSizeSp)
        assertTrue(wideShort.showDueDates)

        // tallest: comfortable with due dates
        val largest = WidgetLayouts.sizeCandidates.maxBy { it.height.value }
        val largeLayout = WidgetLayouts.forSize(largest.width.value.toInt(), largest.height.value.toInt())
        assertEquals(18, largeLayout.taskFontSizeSp)
        assertTrue(largeLayout.showDueDates)

        // medium density reachable too
        val mediumHeights =
            WidgetLayouts.sizeCandidates.map {
                WidgetLayouts.forSize(it.width.value.toInt(), it.height.value.toInt())
            }
        assertTrue(mediumHeights.any { it.taskFontSizeSp == 16 })
    }
}
