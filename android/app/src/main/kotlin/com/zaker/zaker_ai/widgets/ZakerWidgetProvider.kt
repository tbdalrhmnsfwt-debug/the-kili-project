package com.zaker.zaker_ai.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Base class for the app's four home-screen widgets.
 *
 * The original APK declares these four receivers:
 *   * `com.zaker.zaker_ai.widgets.ZToolsWidget`
 *   * `com.zaker.zaker_ai.widgets.ZQuickWidget`
 *   * `com.zaker.zaker_ai.widgets.ZTasksWidget`
 *   * `com.zaker.zaker_ai.widgets.ZImportantWidget`
 *
 * All of them read the same shared state, published from Dart by the
 * `home_widget` package under the `zaker.widget.*` preference keys that
 * were recovered from the original binary.
 */
abstract class ZakerWidgetProvider : HomeWidgetProvider() {

    /** The name of the widget, used as a stable key in [updateWidget]. */
    protected abstract val widgetName: String

    /** How many rows to render per widget (headers drawn differently). */
    protected open val rowCount: Int = 4

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.os.Bundle,
    ) {
        val items = items(context)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_base).apply {
                setTextViewText(R.id.widget_title, title())
                setTextViewText(R.id.widget_subtitle, subtitle(context))
                setTextViewText(R.id.widget_footer, footer(context))

                for (i in 0 until rowCount) {
                    val viewId = itemViewId(i)
                    if (viewId == 0) continue
                    if (i < items.size) {
                        val item = items[i]
                        setTextViewText(viewId, item.first)
                        setViewVisibility(viewId, android.view.View.VISIBLE)
                    } else {
                        setViewVisibility(viewId, android.view.View.GONE)
                    }
                }
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    /** The title shown in the widget header. */
    protected abstract fun title(): String

    /** The list of rows to display, as (primary, secondary) pairs. */
    protected abstract fun items(context: Context): List<Pair<String, String>>

    /** The id of the view for row [index], or 0 when the row does not exist. */
    protected abstract fun itemViewId(index: Int): Int

    /** The subtitle line. */
    protected open fun subtitle(context: Context): String = ""

    /** The footer line. */
    protected open fun footer(context: Context): String = ""

    /** Reads a string published from Dart. */
    protected fun readString(context: Context, key: String, fallback: String = ""): String {
        return try {
            context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                .getString(key, fallback) ?: fallback
        } catch (_: Exception) {
            fallback
        }
    }
}
