# Glance creates action callbacks by reflection (actionRunCallback<T>()) and
# needs their no-argument constructor, which R8 removes otherwise.
-keep class * implements androidx.glance.appwidget.action.ActionCallback {
    <init>();
}
