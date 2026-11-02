package dev.coderoftime.rurana

import android.app.Activity
import android.content.Intent
import android.os.Bundle

// A link tapped in another app starts its activity in that app's task
// unless the app asks for a new one, and singleTop reuses MainActivity
// only on top of its own task: without this hop a second MainActivity,
// with a second Flutter engine on the same databases, would start there.
class TaskLinkActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val link = intent?.data
        if (link != null && link.scheme == SCHEME && link.host == "task") {
            startActivity(
                Intent(this, MainActivity::class.java)
                    .setAction(Intent.ACTION_VIEW)
                    .setData(link)
                    .addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP,
                    ),
            )
        }
        finish()
    }

    private companion object {
        const val SCHEME = "vikunja-dev.coderoftime.rurana"
    }
}
