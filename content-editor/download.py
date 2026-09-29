"""Download a fresh copy of the app's text source. Never overwrite edited files."""
import concurrent.futures
import json
from pathlib import Path
import time
import urllib.request

BASE = "https://cdn.jsdelivr.net/gh/Stringsaeed/azkarify-husn-cdn@v2/v1"
ROOT = Path(__file__).resolve().parents[1] / "content"


def fetch(path):
    for attempt in range(4):
        try:
            with urllib.request.urlopen(BASE + path, timeout=45) as response:
                return json.loads(response.read().decode("utf-8-sig"))
        except Exception:
            if attempt == 3:
                raise
            time.sleep(attempt + 1)


def write(path, data):
    target = ROOT / path.lstrip("/")
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open("x", encoding="utf-8") as file:
        json.dump(data, file, ensure_ascii=False, indent=2)
        file.write("\n")


def main():
    if ROOT.exists():
        raise SystemExit("content/ already exists. Refusing to overwrite downloaded or edited content.")
    indexes = {lang: fetch(f"/{lang}/husn_{lang}.json") for lang in ("ar", "en")}
    paths = [item["detailUrl"] for index in indexes.values() for item in index["items"]]
    # Finish fetching before writing, so network failures do not leave a partial dataset.
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
        documents = dict(zip(paths, pool.map(fetch, paths)))
    for lang, index in indexes.items():
        write(f"/{lang}/husn_{lang}.json", index)
    for path, data in documents.items():
        write(path, data)
    print(f"Downloaded {len(indexes)} indexes and {len(documents)} category files to {ROOT}")
    for lang, index in indexes.items():
        count = sum(len(documents[item["detailUrl"]]["items"]) for item in index["items"])
        print(f"{lang}: {len(index['items'])} categories, {count} entries")


if __name__ == "__main__":
    main()
