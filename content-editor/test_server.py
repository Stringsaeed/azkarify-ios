import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import server


class SaveTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.original = {"items": [{"id": 75, "repeat": 1, "audioUrl": "https://example.com/a.mp3", "text": {"arabic": "ذكر", "arabicTranslated": "", "translated": "Text"}}]}
        for lang in ("ar", "en"):
            (self.root / lang).mkdir()
            (self.root / lang / f"husn_{lang}.json").write_text(json.dumps({"items": [{"id": 27, "title": "Title", "detailUrl": f"/{lang}/27.json", "audioUrl": ""}]}))
            (self.root / lang / '27.json').write_text(json.dumps(self.original))
        self.patcher = patch.object(server, 'ROOT', self.root)
        self.patcher.start()
        self.addCleanup(self.patcher.stop)

    def document(self):
        return next(doc for doc in server.documents() if doc['path'] == 'ar/27.json')

    def test_multiline_unicode_and_count_survive_save_and_reload(self):
        doc = self.document()
        entry = doc['data']['items'][0]
        entry['text']['arabic'] = 'السطر الأول\n\nالسطر الثاني'
        entry['text']['translated'] = 'First line\nSecond line\n'
        entry['repeat'] = 7
        server.save(doc)
        raw = (self.root / 'ar/27.json').read_text()
        self.assertIn('السطر الأول\\n\\nالسطر الثاني', raw)
        self.assertEqual(json.loads(raw)['items'][0]['text']['arabic'], 'السطر الأول\n\nالسطر الثاني')
        self.assertEqual(self.document()['data']['items'][0]['text']['translated'], 'First line\nSecond line\n')
        self.assertEqual(self.document()['data']['items'][0]['repeat'], 7)
        self.assertEqual(json.loads((self.root / 'en/27.json').read_text()), self.original)

    def test_stale_save_does_not_overwrite_a_newer_save(self):
        stale = self.document()
        fresh = copy.deepcopy(stale)
        fresh['data']['items'][0]['repeat'] = 3
        server.save(fresh)
        with self.assertRaises(FileExistsError):
            server.save(stale)
        self.assertEqual(self.document()['data']['items'][0]['repeat'], 3)

    def test_rejects_bad_counts_and_changed_ids_without_writing(self):
        for value in [0, -1, 1.5, True, None, '3']:
            doc = self.document()
            doc['data']['items'][0]['repeat'] = value
            with self.assertRaises(ValueError):
                server.save(doc)
        doc = self.document()
        doc['data']['items'][0]['id'] = 999
        with self.assertRaises(ValueError):
            server.save(doc)
        self.assertEqual(self.document()['data'], self.original)

    def test_rejects_path_outside_known_dataset(self):
        doc = self.document()
        doc['path'] = '../README.md'
        with self.assertRaises(ValueError):
            server.save(doc)

    def test_title_edit(self):
        doc = next(doc for doc in server.documents() if doc['path'] == 'en/husn_en.json')
        doc['data']['items'][0]['title'] = 'New title'
        server.save(doc)
        result = json.loads((self.root / 'en/husn_en.json').read_text())
        self.assertEqual(result['items'][0]['title'], 'New title')


if __name__ == '__main__':
    unittest.main()
