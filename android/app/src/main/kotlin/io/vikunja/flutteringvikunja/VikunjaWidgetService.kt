package io.vikunja.flutteringvikunja

import android.content.Intent
import android.widget.RemoteViewsService

class VikunjaWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return VikunjaWidgetFactory(applicationContext, intent)
    }
}