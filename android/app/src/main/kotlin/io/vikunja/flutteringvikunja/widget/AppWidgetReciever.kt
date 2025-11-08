package io.vikunja.flutteringvikunja.widget


import HomeWidgetGlanceWidgetReceiver

class AppWidgetReciever : HomeWidgetGlanceWidgetReceiver<AppWidget>() {
    override val glanceAppWidget = AppWidget()
}
