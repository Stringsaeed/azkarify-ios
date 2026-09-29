# Content editor

Run from the repository root with Python 3.9 or newer. No packages or build step are needed.

```sh
python3 content-editor/server.py
```

Open [the local editor](http://127.0.0.1:8765). To use a different port, pass `--port 8766`.

Select English or Arabic, search by title, category ID, or any text, and select a category. Edit its title, Arabic text, reading guide, translation, or repetition count. The two language collections are independent: an edit to the English collection does not modify the Arabic collection.

Press Enter in a text field to insert a line break. JSON stores those breaks as `\n` inside strings. The editor restores visible line breaks when you reload, including blank lines and trailing line breaks. The editor does not trim, normalize, or clean text automatically.

**Save changes** writes every changed file directly into `content/`. Unsaved edits stay in memory as you move between categories and languages. Closing or reloading the page with unsaved edits triggers the browser's warning. Files are replaced atomically one at a time; if a save fails, the editor reports what remains unsaved. If another editor or process changes a file, saving it is rejected. Copy your pending edits somewhere safe before reloading to resolve a conflict.

Review saved changes with `git diff -- content`, then commit and push them through your normal workflow. The editor is local: publishing its HTML alone will not let it write repository files. The server listens only on the local computer.

## Dataset

`content/ar/husn_ar.json` and `content/en/husn_en.json` list categories. Each category's `detailUrl` points to its JSON file under `content/`. Original IDs, URLs, item order, and all source fields are preserved. Only JSON indentation and UTF-8 encoding were standardized during download.

Source: the same [Azkarify Hisn CDN v2](https://github.com/Stringsaeed/azkarify-husn-cdn/tree/v2/v1) used by the iOS repository. Downloaded September 29, 2026. Audio URLs are preserved; audio files are not downloaded.

The iOS app has not been switched to these files yet. Bundling this content and replacing its SwiftData/network loading is a separate step.

The download script is retained for reproducibility:

```sh
python3 content-editor/download.py
```

It refuses to run if `content/` already exists, to protect your edits. Do not delete edited content to rerun it.

## Verification

```sh
python3 -m unittest discover -s content-editor -v
```

The tests check multiline Arabic and English round trips, counts, titles, stale saves, and rejected invalid writes.
