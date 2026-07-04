package io.vikunja.app.widget

import androidx.annotation.Keep
import java.util.Date

@Keep
class Task(
    var id: String,
    var title: String,
    var dueDate: Long?,
    var today: Boolean,
) {
    fun dueDateAsDate(): Date? = dueDate?.let { Date(it) }
}
