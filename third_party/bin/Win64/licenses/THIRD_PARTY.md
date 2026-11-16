# Third-party notices

- libtorrent 1.2.19 — Arvid Norberg and contributors, BSD-3-Clause. Source: https://github.com/arvidn/libtorrent/tree/v1.2.19 . Full license: deps/libtorrent/LICENSE . Preserve bundled notices, including bundled third-party code, when redistributing.
- Boost 1.78.0 — Boost contributors, Boost Software License 1.0. Source: https://archives.boost.io/release/1.78.0/source/ . Full license: deps/boost_1_78_0/LICENSE_1_0.txt .
- Delphi/VCL — Embarcadero, governed by the installed Community Edition license. Not relicensed by this repository.
- Windows CryptoAPI — operating system component; not redistributed.

Copy full upstream license files and any bundled third-party notices into release packages. This file does not replace those licenses.

The two native DLLs use the shared Microsoft Visual C++ x64 Runtime (/MD). Install a suitable official redistributable; runtime files are not bundled by these scripts. Keep the compiler, runtime, Boost and libtorrent build settings compatible when updating the engine. See docs/ENGINE-ARCHITECTURE.md and native/dependencies.json.

Fluent System Icons — Microsoft Corporation, MIT license. Selected SVG sources are pinned by commit and SHA-256 in resources/icons/fluent/manifest.json. Prepared PNG variants are embedded in the VCL DFM; no SVG renderer is shipped. Full MIT notice follows (also retained in resources/icons/fluent/LICENSE).

## Fluent System Icons — complete MIT notice

MIT License

Copyright (c) 2020 Microsoft Corporation

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
