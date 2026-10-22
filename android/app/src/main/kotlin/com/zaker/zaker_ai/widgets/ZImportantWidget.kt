package com.zaker.zaker_ai.widgets

import android.content.Context
import com.zaker.zaker_ai.R

/**
 * The "important" widget — surfaces the items the user marked as
 * important (bookmarked lessons, due recall cards, expiring tasks).
 *
 * Published from Dart through the `zaker.widget.important` key.
 */
class ZImportantWidget : ZakerWidgetProvider() {

    override val widgetName: String = "ZImportantWidget"

    override fun title(): String = "مهم"

    override fun itemViewId(index: Int): Int = when (index) {
        0 -> R.id.widget_item_0
        1 -> R.id.widget_item_1
        2 -> R.id.widget_item_2
        3 -> R.id.widget_item_3
        else -> 0
    }

    override fun items(context: Context): List<Pair<String, String>> {
        val raw = readString(context, KEY_IMPORTANT)
        if (raw.isBlank()) return emptyList()
        return raw.split('|')
            .mapNotNull { entry ->
                val parts = entry.split('~')
                if (parts.size < 2) null else parts[0] to parts[1]
            }
    }

    override fun subtitle(context: Context): String =
        readString(context, KEY_IMPORTANT_SIG).ifBlank { "الحاجات اللي محتاج تركز عليها" }

    companion object {
        const val KEY_IMPORTANT = "zaker.widget.important"
        const val KEY_IMPORTANT_SIG = "zaker.widget.importantSig"
    }
}
