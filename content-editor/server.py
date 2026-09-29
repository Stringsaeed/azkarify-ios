"""Local content editor. Python standard library only."""
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[1] / "content"
WEB = Path(__file__).resolve().parent


def revision(data):
    return hashlib.sha256(data).hexdigest()


def documents():
    result = []
    for language in ("ar", "en"):
        paths = [ROOT / language / f"husn_{language}.json"]
        index = json.loads(paths[0].read_text(encoding="utf-8"))
        paths.extend(ROOT / item["detailUrl"].lstrip("/") for item in index["items"])
        for path in paths:
            raw = path.read_bytes()
            result.append({"path": path.relative_to(ROOT).as_posix(), "revision": revision(raw),
                           "data": json.loads(raw)})
    return result


def validate(original, updated, index):
    if not isinstance(updated, dict) or updated.keys() != original.keys():
        raise ValueError("Document fields cannot be added or removed.")
    if not isinstance(updated.get("items"), list) or len(updated["items"]) != len(original["items"]):
        raise ValueError("Entries cannot be added or removed.")
    for key in original.keys() - {"items"}:
        if original[key] != updated[key]:
            raise ValueError("Document metadata must be preserved.")
    for old, new in zip(original["items"], updated["items"]):
        if not isinstance(new, dict) or old.keys() != new.keys():
            raise ValueError("Entry fields cannot be added or removed.")
        editable = {"title"} if index else {"text", "repeat"}
        if any(old[key] != new[key] for key in old.keys() - editable):
            raise ValueError("IDs, order, and source URLs must be preserved.")
        if index:
            if not isinstance(new["title"], str) or not new["title"].strip():
                raise ValueError("Category titles cannot be empty.")
        else:
            if type(new["repeat"]) is not int or not 1 <= new["repeat"] <= 2147483647:
                raise ValueError("Repeat counts must be positive whole numbers.")
            if not isinstance(new["text"], dict) or new["text"].keys() != old["text"].keys():
                raise ValueError("Text fields must be preserved.")
            if not all(isinstance(value, str) for value in new["text"].values()):
                raise ValueError("Text fields must contain text.")


def save(payload):
    allowed = {doc["path"] for doc in documents()}
    name = payload.get("path")
    if not isinstance(name, str) or name not in allowed:
        raise ValueError("Unknown content file.")
    path = ROOT / name
    raw = path.read_bytes()
    if payload.get("revision") != revision(raw):
        raise FileExistsError("This file changed on disk. Reload the editor before saving it.")
    updated = payload.get("data")
    validate(json.loads(raw), updated, path.name.startswith("husn_"))
    encoded = (json.dumps(updated, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as file:
            temporary = file.name
            file.write(encoded)
            file.flush()
            os.fsync(file.fileno())
        os.replace(temporary, path)
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)
    return {"revision": revision(encoded)}


class Handler(BaseHTTPRequestHandler):
    def respond(self, status, body, content_type="application/json; charset=utf-8"):
        if not isinstance(body, bytes):
            body = json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def local_request(self):
        allowed = {f"127.0.0.1:{self.server.server_port}", f"localhost:{self.server.server_port}"}
        if self.headers.get("Host") not in allowed:
            self.respond(403, {"error": "Use the local editor URL."})
            return False
        origin = self.headers.get("Origin")
        if origin and origin not in {f"http://{host}" for host in allowed}:
            self.respond(403, {"error": "Cross-origin requests are not allowed."})
            return False
        return True

    def do_GET(self):
        if not self.local_request():
            return
        if self.path == "/api/documents":
            try:
                self.respond(200, {"documents": documents()})
            except (OSError, ValueError, KeyError) as error:
                self.respond(500, {"error": str(error)})
            return
        assets = {"/": ("index.html", "text/html"), "/app.js": ("app.js", "text/javascript"),
                  "/style.css": ("style.css", "text/css")}
        if self.path not in assets:
            self.respond(404, {"error": "Not found."})
            return
        name, mime = assets[self.path]
        self.respond(200, (WEB / name).read_bytes(), mime + "; charset=utf-8")

    def do_POST(self):
        if not self.local_request():
            return
        if self.path != "/api/save":
            self.respond(404, {"error": "Not found."})
            return
        try:
            if self.headers.get("Content-Type") != "application/json":
                raise ValueError("Expected application/json.")
            size = int(self.headers.get("Content-Length", "0"))
            if not 0 < size <= 5_000_000:
                raise ValueError("Invalid request size.")
            payload = json.loads(self.rfile.read(size))
            if not isinstance(payload, dict):
                raise ValueError("Expected a JSON object.")
            self.respond(200, save(payload))
        except FileExistsError as error:
            self.respond(409, {"error": str(error)})
        except (ValueError, KeyError, TypeError) as error:
            self.respond(400, {"error": str(error)})
        except OSError as error:
            self.respond(500, {"error": f"Could not save: {error}"})


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    server = HTTPServer(("127.0.0.1", args.port), Handler)
    print(f"Content editor: http://127.0.0.1:{args.port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()
