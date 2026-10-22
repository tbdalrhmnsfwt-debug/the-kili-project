package com.zaker.zaker_ai.widgets

import android.content.Context
import com.zaker.zaker_ai.R

/**
 * The "quick" widget — a short list of shortcuts the user pins to the
 * home screen.
 *
 * The pinned list is published from Dart through the
 * `zaker.widget.quick` key as a `|`-separated list of `~`-joined
 * (label, route) pairs.
 */
class ZQuickWidget : ZakerWidgetProvider() {

    override val widgetName: String = "ZQuickWidget"

    override fun title(): String = "وصول سريع"

    override fun itemViewId(index: Int): Int = when (index) {
        0 -> R.id.widget_item_0
        1 -> R.id.widget_item_1
        2 -> R.id.widget_item_2
        3 -> R.id.widget_item_3
        else -> 0
    }

    override fun items(context: Context): List<Pair<String, String>> {
        val raw = readString(context, KEY_QUICK)
        if (raw.isBlank()) return emptyList()
        return raw.split('|')
            .mapNotNull { entry ->
                val parts = entry.split('~')
                if (parts.size < 2) null else parts[0] to parts[1]
            }
    }

    override fun subtitle(context: Context): String =
        readString(context, KEY_QUICK_SIG).ifBlank { "اختصاراتك المحفوظة" }

    companion object {
        const val KEY_QUICK = "zaker.widget.quick"
        const val KEY_QUICK_SIG = "zaker.widget.quickSig"
    }
}
