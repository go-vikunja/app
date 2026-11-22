# vikunja_storage_flush

Android's `SharedPreferences.apply()` writes to disk only after a delay, so a
process killed meanwhile loses the change. `StorageFlush.flushSharedPreferences`
waits until a file's pending changes are on disk. The app uses it after storing
rotated tokens, which the server has already replaced
([Sessions](../../docs/decisions.md#sessions)). It does nothing on other
platforms.
