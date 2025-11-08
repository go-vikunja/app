package io.vikunja.flutteringvikunja.widget
import androidx.annotation.Keep
import java.util.Date

@Keep
class Task (
    var id: String,
    var title: String,
    var dueDate: Date,
    var today: Boolean,
    var overdue: Boolean,
    )
