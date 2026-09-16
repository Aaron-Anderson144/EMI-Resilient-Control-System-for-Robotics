"""Portable workspace boundaries for both preserved scientific freezes."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("workbench_bundle", Path(__file__).resolve().parents[1] / "desktop/bundle_workspace.py")
bundle = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bundle)


class BundleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.source = Path(self.temp.name) / "source"
        self.destination = Path(self.temp.name) / "bundle"
        for name, content in [("original.m", "original"), ("protocol.json", "protocol"),
                              (bundle.ENGINE_SOURCE, "old engine"), (bundle.V2_ENGINE_SOURCE, "v2 engine")]:
            self.write(name, content)
        for source, relative in [(bundle.ENGINE_SOURCE, "FOUR_WAY/work/fourway_exact_"),
                                 (bundle.V2_ENGINE_SOURCE, "FOUR_WAY_V2/work/fourway_v2_exact_")]:
            self.write("06_Circuit_Simulations/" + relative + bundle.digest(self.source / source)[:16] + ".mexw64", "binary fixture")
        for manifest, target in [(bundle.FREEZE, "original.m"), (bundle.V2_FREEZE, "protocol.json")]:
            path = self.source / target
            self.write(manifest, json.dumps({"files": [{"path": target, "bytes": path.stat().st_size, "sha256": bundle.digest(path)}]}))
        self.write(bundle.DEPENDENCIES, '{"files": []}')
        for name in ["SOURCE_DIRECTORIES", "ROOT_PATTERNS", "DOCUMENTS"]:
            replacement = patch.object(bundle, name, ())
            replacement.start()
            self.addCleanup(replacement.stop)

    def write(self, relative, content):
        path = self.source / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def test_both_freezes_and_source_identified_engines_are_included(self):
        result = bundle.build_workspace(self.source, self.destination)
        self.assertEqual(result["original_freeze_files_verified"], 1)
        self.assertEqual(result["v2_protocol_files_verified"], 1)
        for key in ["receiver_binary_path", "v2_receiver_binary_path"]:
            path = result["runtime"][key]
            self.assertEqual((self.destination / path).read_bytes(), (self.source / path).read_bytes())

    def test_v2_protocol_tampering_fails_before_copy(self):
        self.write("protocol.json", "changed protocol")
        with self.assertRaisesRegex(ValueError, "Pinned input differs"):
            bundle.build_workspace(self.source, self.destination)
        self.assertFalse(self.destination.exists())

    def test_stale_v2_binary_is_not_substituted(self):
        self.write(bundle.V2_ENGINE_SOURCE, "new engine")
        with self.assertRaisesRegex(ValueError, "Required workspace file is missing.*fourway_v2_exact_"):
            bundle.build_workspace(self.source, self.destination)
        self.assertFalse(self.destination.exists())

    def test_imported_history_is_excluded_while_native_runs_remain(self):
        for suffix, imported in [("123456abcdef", True), ("abcdef123456", False)]:
            run_id = "20260915T120000Z_" + suffix
            record = {"id": run_id, "workflow": "baseline", "status": "completed"}
            if imported:
                record["provenance"] = {"kind": "imported_completed_development_evidence"}
            self.write(f"12_Workbench/runs/{run_id}/run.json", json.dumps(record))
        result = bundle.build_workspace(self.source, self.destination)
        self.assertEqual([r["id"] for r in result["saved_completed_runs"]], ["20260915T120000Z_abcdef123456"])
        self.assertFalse((self.destination / "12_Workbench/runs/20260915T120000Z_123456abcdef").exists())
        self.assertTrue((self.source / "12_Workbench/runs/20260915T120000Z_123456abcdef/run.json").is_file())
