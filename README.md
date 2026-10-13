# web-build

Generated Godot web export of `godot/` from the `godot-engine` branch. Not source.
`index.wasm.gz` is the engine binary, gzipped; `index.html` inflates it in the
browser. Rebuild with:

    godot --headless --path godot --export-release Web godot/export/web/index.html
    gzip -9 -k godot/export/web/index.wasm
