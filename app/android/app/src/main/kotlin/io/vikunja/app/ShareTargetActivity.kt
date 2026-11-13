package io.vikunja.app

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.os.Process

// Shares land here, not on MainActivity, for the same reason as task
// links: started in the sending app's task, MainActivity would bring up a
// second Flutter engine there. The grants for the shared files are passed
// on with the forwarded intent, so MainActivity holds its own once this
// activity is gone.
class ShareTargetActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val received = intent
        val action = received?.action
        if (savedInstanceState == null &&
            (action == Intent.ACTION_SEND || action == Intent.ACTION_SEND_MULTIPLE)
        ) {
            forward(received)
        }
        finish()
    }

    // Only a grant this activity holds can be passed on; the system throws
    // for any other, which a sender that names a file it did not grant
    // would otherwise turn into a crash. Then only the files granted to
    // this activity go, and at last the text alone.
    private fun forward(received: Intent) {
        val uris = ShareInbox.streamsOf(received).filter { ShareInbox.isForeignContent(this, it) }
        val attempts = listOf(uris, uris.filter { isGrantedToMe(it) }, emptyList()).distinct()
        for (streams in attempts) {
            try {
                startActivity(forwarded(received, streams))
                return
            } catch (_: SecurityException) {
                // The next attempt passes on less.
            }
        }
    }

    private fun isGrantedToMe(uri: Uri): Boolean =
        checkUriPermission(
            uri,
            Process.myPid(),
            Process.myUid(),
            Intent.FLAG_GRANT_READ_URI_PERMISSION,
        ) == PackageManager.PERMISSION_GRANTED

    private fun forwarded(received: Intent, uris: List<Uri>): Intent {
        val forward = Intent(this, MainActivity::class.java)
            .setAction(ShareInbox.ACTION_SHARE)
            .addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP,
            )
        ShareInbox.textExtra(received, Intent.EXTRA_SUBJECT)?.let {
            forward.putExtra(Intent.EXTRA_SUBJECT, it)
        }
        ShareInbox.textExtra(received, Intent.EXTRA_TEXT)?.let {
            forward.putExtra(Intent.EXTRA_TEXT, it)
        }
        if (uris.isNotEmpty()) {
            val clip = ClipData.newRawUri(null, uris.first())
            uris.drop(1).forEach { clip.addItem(ClipData.Item(it)) }
            forward.clipData = clip
            forward.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return forward
    }
}
