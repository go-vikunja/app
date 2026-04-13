package io.vikunja.app.widget


import HomeWidgetGlanceWidgetReceiver

class AppWidgetReciever : HomeWidgetGlanceWidgetReceiver<AppWidget>() {
    override val glanceAppWidget = AppWidget()
}
