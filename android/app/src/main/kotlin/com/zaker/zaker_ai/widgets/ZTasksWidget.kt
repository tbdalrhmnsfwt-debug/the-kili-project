package com.zaker.zaker_ai.widgets

import android.content.Context
import com.zaker.zaker_ai.R

/**
 * The "tasks" widget — shows the study tasks scheduled for today.
 *
 * The list is derived on the Dart side from the planner's
 * `zaker.planner.tasks.v1` preference and published through
 * `zaker.widget.tasks`.
 */
class ZTasksWidget : ZakerWidgetProvider() {

    override val widgetName: String = "ZTasksWidget"

    override fun title(): String = "مهام اليوم"

    override fun itemViewId(index: Int): Int = when (index) {
        0 -> R.id.widget_item_0
        1 -> R.id.widget_item_1
        2 -> R.id.widget_item_2
        3 -> R.id.widget_item_3
        else -> 0
    }

    override fun items(context: Context): List<Pair<String, String>> {
        val raw = readString(context, KEY_TASKS)
        if (raw.isBlank()) return emptyList()
        return raw.split('|')
            .mapNotNull { entry ->
                val parts = entry.split('~')
                if (parts.size < 2) null else parts[0] to parts[1]
            }
    }

    override fun subtitle(context: Context): String {
        val count = readString(context, KEY_TASKS_COUNT)
        return if (count.isBlank()) "مهامك المقررة" else "عندك $count مهمة النهارده"
    }

    companion object {
        const val KEY_TASKS = "zaker.widget.tasks"
        const val KEY_TASKS_COUNT = "zaker.widget.tasksCount"
    }
}
