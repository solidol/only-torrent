# Third-party notices

- libtorrent 1.2.19 — Arvid Norberg and contributors, BSD-3-Clause. Source: https://github.com/arvidn/libtorrent/tree/v1.2.19 . Full license: deps/libtorrent/LICENSE . Preserve bundled notices, including bundled third-party code, when redistributing.
- Boost 1.78.0 — Boost contributors, Boost Software License 1.0. Source: https://archives.boost.io/release/1.78.0/source/ . Full license: deps/boost_1_78_0/LICENSE_1_0.txt .
- Delphi/VCL — Embarcadero, governed by the installed Community Edition license. Not relicensed by this repository.
- Windows CryptoAPI — operating system component; not redistributed.

Copy full upstream license files and any bundled third-party notices into release packages. This file does not replace those licenses.

The two native DLLs use the shared Microsoft Visual C++ x64 Runtime (/MD). Install a suitable official redistributable; runtime files are not bundled by these scripts. Keep the compiler, runtime, Boost and libtorrent build settings compatible when updating the engine. See docs/ENGINE-ARCHITECTURE.md and native/dependencies.json.
