package io.vikunja.flutteringvikunja.widget


import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

class AppWidgetReciever : HomeWidgetGlanceWidgetReceiver<AppWidget>() {
    override val glanceAppWidget = AppWidget()
}
