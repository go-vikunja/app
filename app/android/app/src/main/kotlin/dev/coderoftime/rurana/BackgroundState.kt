package dev.coderoftime.rurana

import android.app.usage.UsageStatsManager

internal object BackgroundState {
    // Exempted (5) and never (50) are hidden constants, not public buckets.
    fun bucketName(bucket: Int): String = when (bucket) {
        UsageStatsManager.STANDBY_BUCKET_ACTIVE -> "active"
        UsageStatsManager.STANDBY_BUCKET_WORKING_SET -> "workingSet"
        UsageStatsManager.STANDBY_BUCKET_FREQUENT -> "frequent"
        UsageStatsManager.STANDBY_BUCKET_RARE -> "rare"
        UsageStatsManager.STANDBY_BUCKET_RESTRICTED -> "restricted"
        else -> "other"
    }

    // Dart waits for the answer, so a value that cannot be read is left out
    // instead of failing the call.
    fun collect(reads: Map<String, () -> Any>): Map<String, Any> = buildMap {
        for ((key, read) in reads) {
            val value = try {
                read()
            } catch (_: Exception) {
                continue
            }
            put(key, value)
        }
    }
}
