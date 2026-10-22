package com.zaker.zaker_ai.widgets

import android.content.Context
import com.zaker.zaker_ai.R

/**
 * The "tools" widget — shows the user's pinned tools.
 *
 * The pinned list lives in the `zaker.pinnedTools.v1` and
 * `zaker.toolsOrder` preferences, published to the widget through
 * `zaker.widget.tools`.
 */
class ZToolsWidget : ZakerWidgetProvider() {

    override val widgetName: String = "ZToolsWidget"

    override fun title(): String = "أدواتك"

    override fun itemViewId(index: Int): Int = when (index) {
        0 -> R.id.widget_item_0
        1 -> R.id.widget_item_1
        2 -> R.id.widget_item_2
        3 -> R.id.widget_item_3
        else -> 0
    }

    override fun items(context: Context): List<Pair<String, String>> {
        val raw = readString(context, KEY_TOOLS)
        if (raw.isBlank()) return emptyList()
        return raw.split('|')
            .mapNotNull { entry ->
                val parts = entry.split('~')
                if (parts.size < 2) null else parts[0] to parts[1]
            }
    }

    override fun subtitle(context: Context): String =
        readString(context, KEY_TOOLS_SIG).ifBlank { "اختار الأدوات اللي بتستخدمها" }

    companion object {
        const val KEY_TOOLS = "zaker.widget.tools"
        const val KEY_TOOLS_SIG = "zaker.widget.iconsSig"
    }
}
