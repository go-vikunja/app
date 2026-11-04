package io.vikunja.app.widget

import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp

/**
 * The layout traits a widget instance renders with at one responsive size:
 * density (task font, row padding), optional content dropped when space is
 * scarce (section labels, due-date column), and the number of task rows that
 * fit in the instance. Produced by [WidgetLayouts.forSize] from the size
 * Glance reports via `LocalSize`.
 *
 * [maxTaskRows] is the capacity model, not a render cap: the task list
 * scrolls, so every task stays reachable. Its job is deciding when the
 * instance is too short for even one row ([isHeaderOnly]) or for the empty
 * view; truncating at it would hide tasks scrolling already reaches.
 */
data class WidgetLayout(
    val taskFontSizeSp: Int,
    val sectionLabelFontSizeSp: Int,
    val rowPaddingDp: Int,
    val showSectionLabels: Boolean,
    val showDueDates: Boolean,
    val maxTaskRows: Int,
) {
    /** Sizes too short for even one task row render the title bar alone. */
    val isHeaderOnly: Boolean
        get() = maxTaskRows == 0
}

/**
 * Derives a widget instance's [WidgetLayout] from its size. Heights map onto
 * three density tiers — compact (dense: small font, tight padding), medium,
 * comfortable — so short instances show a dense list while tall ones show
 * more rows at full size. Widths below [DUE_DATE_MIN_WIDTH_DP] drop the
 * due-date column so task titles keep room; heights below the comfortable
 * tier drop the section labels, which would otherwise cost a row each.
 *
 * [maxTaskRows] models what fits: title bar (48dp) plus list padding minus
 * the section labels, divided by the row height. Instances shorter than one
 * row are [WidgetLayout.isHeaderOnly] rather than clipping half a row.
 */
object WidgetLayouts {
    /** Heights below this render the compact tier. */
    const val COMPACT_MAX_HEIGHT_DP = 130

    /** Heights at or above this render the comfortable tier. */
    const val COMFORTABLE_MIN_HEIGHT_DP = 260

    /** Widths below this drop the due-date column. */
    const val DUE_DATE_MIN_WIDTH_DP = 250

    /** Section labels ("Today:", "Overdue:", …) use one fixed size. */
    const val SECTION_LABEL_FONT_SP = 14

    private const val HEADER_HEIGHT_DP = 48
    private const val LIST_PADDING_DP = 8

    /** Density traits per height tier, thickest last. */
    private data class Density(val taskFontSp: Int, val rowPaddingDp: Int)

    private val compact = Density(taskFontSp = 14, rowPaddingDp = 4)
    private val medium = Density(taskFontSp = 16, rowPaddingDp = 6)
    private val comfortableDensity = Density(taskFontSp = 18, rowPaddingDp = 8)

    /**
     * The responsive size buckets the widget is rendered for (Glance picks
     * the best fit for the instance's actual size and reports it through
     * `LocalSize`); every tier and due-date mode is reachable from this set.
     */
    val sizeCandidates: Set<DpSize> = setOf(
        DpSize(180.dp, 100.dp),
        DpSize(320.dp, 100.dp),
        DpSize(180.dp, 180.dp),
        DpSize(250.dp, 260.dp),
        DpSize(320.dp, 450.dp),
    )

    /**
     * The layout for a widget instance of the given size.
     * [sectionCount] is how many of the widget's task sections actually hold
     * tasks (0-2); its labels only reserve height when shown.
     */
    fun forSize(widthDp: Int, heightDp: Int, sectionCount: Int = 2): WidgetLayout {
        val density = when {
            heightDp < COMPACT_MAX_HEIGHT_DP -> compact
            heightDp >= COMFORTABLE_MIN_HEIGHT_DP -> comfortableDensity
            else -> medium
        }
        val showSectionLabels = heightDp >= COMFORTABLE_MIN_HEIGHT_DP
        return WidgetLayout(
            taskFontSizeSp = density.taskFontSp,
            sectionLabelFontSizeSp = SECTION_LABEL_FONT_SP,
            rowPaddingDp = density.rowPaddingDp,
            showSectionLabels = showSectionLabels,
            showDueDates = widthDp >= DUE_DATE_MIN_WIDTH_DP,
            maxTaskRows = maxTaskRows(
                heightDp,
                density,
                showSectionLabels,
                sectionCount,
            ),
        )
    }

    private fun maxTaskRows(
        heightDp: Int,
        density: Density,
        showSectionLabels: Boolean,
        sectionCount: Int,
    ): Int {
        val bodyHeight = heightDp - HEADER_HEIGHT_DP - 2 * LIST_PADDING_DP
        val labelReserve =
            if (showSectionLabels) {
                sectionCount.coerceIn(0, 2) * lineHeightDp(SECTION_LABEL_FONT_SP)
            } else {
                0
            }
        val rowHeight = lineHeightDp(density.taskFontSp) + 2 * density.rowPaddingDp
        return ((bodyHeight - labelReserve) / rowHeight).coerceAtLeast(0)
    }

    /** Line height estimate for a font size, at the default font scale. */
    private fun lineHeightDp(fontSp: Int): Int = fontSp * 4 / 3
}
