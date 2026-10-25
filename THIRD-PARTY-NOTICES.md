# Third-party notices

## GStreamer matroska plugin (src/matroska)

GStreamer is licensed under the GNU Lesser General Public License version 2.1 or later.
The files in `src/matroska` are LG Electronics' webOS 22 version of the GStreamer 1.18.2
matroska plugin, taken from LG's open-source package "webOS 22 KHP 12.0"
(https://opensource.lge.com), plus Dolby Vision code derived from LG's webOS 25 sources
(https://github.com/lgstreamer/gstreamer-webos-25). Copyright notices in the individual
files apply. `build/config.h` is the configuration header from LG's build of the same
package.

## libdovi (statically linked into the release binary)

https://github.com/quietvoid/dovi_tool (crate `dolby_vision`, C API)

```
MIT License

Copyright (c) 2026 quietvoid

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

## Test data

`tests/` refers to dovi_tool's test assets (`assets/tests/mel_orig.bin`,
`fel_orig.bin`, `mel_to_81.bin`, MIT, see above); they are not included here.