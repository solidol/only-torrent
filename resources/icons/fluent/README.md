# Only Torrent: Fluent System Icons

Source: Microsoft fluentui-system-icons, MIT. Exact revision and original SVG hashes: manifest.json; PNG hashes and palettes: generated.json. The transfer glyph combines two upstream arrows; the other glyphs are recolored upstream filled icons.

Only the selected SVGs and prepared PNGs are kept. Light/dark variants use 20, 24, 32, 40, 48 and 64 pixel sources. The text DFM embeds these PNGs in ImageCollectionMain; VirtualImageListMain presents the current theme at the form DPI. No renderer, fonts, Node or external image files are required by the installed application.

Explicit asset refresh (never part of a normal build):

1. python tools/fetch-fluent-icons.py --fetch [--commit REVISION]
2. npm.cmd install --prefix build/icon-tools --ignore-scripts --no-audit --no-fund @resvg/resvg-js@2.6.2
3. node tools/prepare-fluent-icons.cjs

Commit the SVG/PNG files, generated DFM and license/manifest changes. The updater and MSI use the ready Delphi resources. Build-time resvg is not distributed.
