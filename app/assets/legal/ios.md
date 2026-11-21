# Third-party notices: iOS libraries

The iOS app links these Swift packages, which plugins fetch by URL, into the
app besides the Flutter engine and the Dart packages. `tool/ci/ios_notices.py`
checks that each package the build resolved is here, with its version and its
licence file; edit this file by hand when a package changes.

- sentry-apple-binaries 9.34.0 (MIT): the Sentry SDK for Apple platforms
  (sentry-cocoa), linked statically by sentry_flutter for the opt-in crash
  reports

```text
The MIT License (MIT)

Copyright (c) 2015 Sentry

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
