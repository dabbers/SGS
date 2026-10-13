# tools

## web_shell.html

The page published at https://preview.dab.im/sgs/. It is Godot's exported
`index.html` with two changes:

1. All runtime files (`index.js`, `index.pck`, worklets, icons) load from the
   `web-build` branch of this repo through jsDelivr, pinned to a commit.
2. The 39 MB `index.wasm` is fetched as `index.wasm.gz`, inflated in the
   browser with `DecompressionStream`, and handed to Godot's loader through a
   `fetch` / `XMLHttpRequest` shim as a `blob:` URL.

To publish a new build:

    cd godot
    godot --headless --path . --export-release Web export/web/index.html
    gzip -9 -k -f export/web/index.wasm
    # copy export/web/* (minus index.wasm) onto the web-build branch, commit, push
    # then replace the commit hash in this file and the index.pck size in fileSizes
