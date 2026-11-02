package android.util

// Ahead of android.jar's Log, whose methods throw on the JVM: ExifInterface
// asks isLoggable when its class loads.
@Suppress("unused", "UNUSED_PARAMETER")
object Log {
    @JvmStatic
    fun isLoggable(tag: String?, level: Int): Boolean = false

    @JvmStatic
    fun d(tag: String?, message: String?): Int = 0

    @JvmStatic
    fun i(tag: String?, message: String?): Int = 0

    @JvmStatic
    fun w(tag: String?, message: String?): Int = 0

    @JvmStatic
    fun w(tag: String?, message: String?, error: Throwable?): Int = 0

    @JvmStatic
    fun w(tag: String?, error: Throwable?): Int = 0

    @JvmStatic
    fun e(tag: String?, message: String?): Int = 0

    @JvmStatic
    fun e(tag: String?, message: String?, error: Throwable?): Int = 0
}
