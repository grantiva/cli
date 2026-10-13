#!/usr/bin/env python3
"""Isolated fake-filesystem/subprocess checks for task9_source_window.py."""
import importlib.util
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("source_window", HERE / "task9_source_window.py")
sw = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sw)


class SourceWindowFixtures(unittest.TestCase):
    def test_fake_full_controller_closes_on_zero_exit_swift_home_contamination(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw).resolve(); fakebin = root / "bin"; fakebin.mkdir()
            repos = {}
            for name, head in (("cli", sw.CLI_SHA), ("runner", sw.RUNNER_SHA), ("demo", sw.DEMO_SHA)):
                repo = root / name; repo.mkdir(); (repo / "tracked.txt").write_text(name)
                repos[name] = repo
            (repos["runner"] / "go.mod").write_text("module example.test/mod\n")
            git_script = fakebin / "git"
            git_script.write_text("""#!/usr/bin/env python3
import os,sys
repo=sys.argv[sys.argv.index('-C')+1]; command=sys.argv[sys.argv.index('-C')+2]
heads={'cli':'%s','runner':'%s','demo':'%s'}
if command=='rev-parse': print(heads[os.path.basename(repo)])
elif command=='status': pass
elif command=='ls-files': os.write(1,b'tracked.txt\\0')
else: raise SystemExit(2)
""" % (sw.CLI_SHA, sw.RUNNER_SHA, sw.DEMO_SHA))
            git_script.chmod(0o755)
            swift_script = fakebin / "swift"
            swift_script.write_text("""#!/usr/bin/env python3
import os,pathlib
pathlib.Path(os.environ['GRANTIVA_RUNNER_HOME'],'unexpected').mkdir(parents=True)
pathlib.Path('tracked.txt').unlink()
print('fake swift success')
""")
            swift_script.chmod(0o755)
            candidate = root / "candidate.json"; gate = root / "gate.json"; review = root / "review.md"
            cleanup = root / "cleanup.json"; ownership_path = root / "ownership.json"
            provision = root / "provision.json"; shutdown = root / "shutdown.json"; output = root / "output"
            candidate.write_text(json.dumps({"schema":"grantiva.task9.candidate.v1",
                "task8CandidateManifestSHA256":sw.BOUND_TASK8_CANDIDATE_SHA,
                "cli":{"repoPath":str(repos["cli"]),"sourceSHA":sw.CLI_SHA},
                "runner":{"repoPath":str(repos["runner"]),"sourceSHA":sw.RUNNER_SHA},
                "demo":{"repoPath":str(repos["demo"]),"sourceSHA":sw.DEMO_SHA}}))
            review.write_text("# fake approved review\n"); cleanup.write_text('{"passed":true}\n')
            gate.write_text(json.dumps({"schema":"grantiva.task8.zero-gate.v1","passed":True,
                "candidateManifestSHA256":sw.sha256(candidate),
                "review":{"path":str(review),"sha256":sw.sha256(review)},
                "cleanup":{"path":str(cleanup),"sha256":sw.sha256(cleanup)}}))
            ownership = {"schema":"grantiva.task9.primary-ownership.v1",
                "candidateManifestSHA256":sw.sha256(candidate),"gateEvidence":str(gate),
                "devices":{"android":{"owned":True,"name":"cov4-android","avd":"cov4-android",
                    "id":"emulator-5584","ownedPIDs":[321],"launch":{"pid":321,
                    "argv":["emulator","-avd","cov4-android","-port","5584"]}}}}
            ownership_path.write_text(json.dumps(ownership))
            provision.write_text(json.dumps({"schema":"grantiva.task9.primary-provision.v1","passed":True,
                "candidateManifestSHA256":sw.sha256(candidate),"gateEvidenceSHA256":sw.sha256(gate),
                "ownership":ownership}))
            shutdown.write_text(json.dumps({"schema":"grantiva.task9.android-shutdown-transition.v1",
                "passed":True,"state":"created-shutdown","candidateManifestSHA256":sw.sha256(candidate),
                "primaryProvisionSHA256":sw.sha256(provision),"gateEvidenceSHA256":sw.sha256(gate),
                "allocation":{"avd":"cov4-android","serial":"emulator-5584","pid":321},
                "ownership":{"path":str(ownership_path),"sha256":sw.sha256(ownership_path)}}))
            inventory = HERE / "task9-source-window-command-inventory-draft.json"
            old_argv, old_path = sys.argv, os.environ.get("PATH", "")
            sys.argv = ["task9_source_window.py", "--candidate", str(candidate), "--gate", str(gate),
                "--provision", str(provision), "--shutdown", str(shutdown), "--inventory", str(inventory),
                "--output", str(output), "--phase", "execute", "--command", "swift-l74-json", "--timeout", "2"]
            os.environ["PATH"] = str(fakebin) + os.pathsep + old_path
            try:
                sw.main()
            finally:
                sys.argv = old_argv; os.environ["PATH"] = old_path
            manifest = json.loads((output / "source-window-manifest.json").read_text())
            failure = json.loads((output / "terminal-failure.json").read_text())
            postflight = json.loads((output / "commands/swift-l74-json/postflight.json").read_text())
            self.assertEqual(manifest["status"], "CLOSED_NONPASS_UNREVIEWED")
            self.assertIn("nonempty-GRANTIVA_RUNNER_HOME", failure["reasons"])
            self.assertIn("invalid-tracked-entries", failure["reasons"])
            self.assertEqual(failure["observedSource"]["trackedEntryIssues"],
                             [{"issue":"missing","path":"tracked.txt"}])
            self.assertFalse(postflight["passed"])
            self.assertEqual((output / "commands/swift-l74-json/stdout.bin").read_text(), "fake swift success\n")

    def test_bounded_runner_keeps_complete_streams_and_refuses_overwrite(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw); out = root / "evidence"; out.mkdir()
            result = sw.run_bounded(
                ["python3", "-c", "import sys; print('out'); print('err', file=sys.stderr)"],
                root, {}, 2, out)
            self.assertEqual(result["exit"], 0)
            self.assertEqual((out / "stdout.bin").read_bytes(), b"out\n")
            self.assertEqual((out / "stderr.bin").read_bytes(), b"err\n")
            marker = root / "must-not-run"
            with self.assertRaises(RuntimeError):
                sw.run_bounded(["python3", "-c", f"open({str(marker)!r},'w').close()"], root, {}, 2, out)
            self.assertFalse(marker.exists())

    def test_timeout_is_bounded_and_retains_partial_stream(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw); out = root / "timeout"; out.mkdir()
            result = sw.run_bounded(
                ["python3", "-c", "import time,sys; print('before', flush=True); time.sleep(2)"],
                root, {}, .05, out)
            self.assertTrue(result["timedOut"])
            self.assertIsNone(result["exit"])
            self.assertEqual((out / "stdout.bin").read_bytes(), b"before\n")

    def test_inventory_proposal_rejects_duplicate_and_outside_module(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw); (root / "go.mod").write_text("module example.test/mod\n")
            good = root / "good"; good.write_bytes(b"example.test/mod/a\nexample.test/mod/b\n")
            proof = {"head": sw.RUNNER_SHA, "status": "", "trackedTreeSHA256": "tree"}
            packages = sw.freeze_inventory_proposal(good, root, root / "proposal.json", "candidate", proof)
            self.assertEqual(packages, ["example.test/mod/a", "example.test/mod/b"])
            for name, value in (("duplicate", b"example.test/mod/a\nexample.test/mod/a\n"),
                                ("outside", b"elsewhere.test/pkg\n")):
                path = root / name; path.write_bytes(value)
                with self.assertRaises(RuntimeError):
                    sw.freeze_inventory_proposal(path, root, root / f"{name}.json", "candidate", proof)

    def test_reviewed_packages_require_hash_review_and_literal_module_paths(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw); (root / "go.mod").write_text("module example.test/mod\n")
            candidate_hash = "c" * 64
            runner_proof = {"realpath": str(root), "head": sw.RUNNER_SHA, "status": "",
                            "trackedFileCount": 1, "trackedTreeSHA256": "tree"}
            stdout = root / "stdout.bin"; stdout.write_bytes(b"example.test/mod/a\nexample.test/mod/b\n")
            result = root / "inventory-result.json"
            result.write_text(json.dumps({"timedOut": False, "exit": 0,
                "stdout": {"sha256": sw.sha256(stdout)}}) + "\n")
            start = root / "start.json"
            start.write_text(json.dumps({"commandId": "go-inventory", "argv": [["go", "list", "./..."]],
                "candidateManifestSHA256": candidate_hash, "source": runner_proof}) + "\n")
            review = root / "review.json"; review.write_text('{"approved":true}\n')
            proposal = root / "proposal.json"
            proposal.write_text(json.dumps({"schema": "grantiva.task9.go-packages.proposal.v1",
                "approved": False, "inventoryStdoutSHA256": sw.sha256(stdout),
                "candidateManifestSHA256": candidate_hash, "source": runner_proof,
                "packages": ["example.test/mod/a", "example.test/mod/b"]}) + "\n")
            artifact = root / "packages.json"
            artifact.write_text(json.dumps({
                "schema": "grantiva.task9.go-packages.v1", "approved": True,
                "inventoryResultSHA256": sw.sha256(result),
                "review": {"path": str(review), "sha256": sw.sha256(review)},
                "inventoryStart": {"path": str(start), "sha256": sw.sha256(start)},
                "inventoryStdout": {"path": str(stdout), "sha256": sw.sha256(stdout)},
                "inventoryProposal": {"path": str(proposal), "sha256": sw.sha256(proposal)},
                "packages": ["example.test/mod/a", "example.test/mod/b"]}) + "\n")
            packages, chain = sw.package_artifact(artifact, result, root, candidate_hash, runner_proof)
            self.assertEqual(packages, ["example.test/mod/a", "example.test/mod/b"])
            self.assertEqual(chain["inventoryStdout"]["sha256"], sw.sha256(stdout))
            doc = json.loads(artifact.read_text()); doc["packages"] = ["./..."]
            artifact.write_text(json.dumps(doc))
            with self.assertRaises(RuntimeError):
                sw.package_artifact(artifact, result, root, candidate_hash, runner_proof)

    def test_go_chain_rejects_failed_raw_and_candidate_source_mismatches(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw); (root / "go.mod").write_text("module example.test/mod\n")
            stdout = root / "stdout"; stdout.write_bytes(b"example.test/mod/a\n")
            proof = {"head": sw.RUNNER_SHA, "status": ""}; candidate = "c" * 64
            start = root / "start"; review = root / "review"; proposal = root / "proposal"; result = root / "result"
            start.write_text(json.dumps({"commandId":"go-inventory","argv":[["go","list","./..."]],
                "candidateManifestSHA256":candidate,"source":proof}))
            review.write_text('{"approved":true}')
            proposal.write_text(json.dumps({"schema":"grantiva.task9.go-packages.proposal.v1","approved":False,
                "inventoryStdoutSHA256":sw.sha256(stdout),"candidateManifestSHA256":candidate,
                "source":proof,"packages":["example.test/mod/a"]}))
            def write_artifact():
                artifact = root / "artifact"
                artifact.write_text(json.dumps({"schema":"grantiva.task9.go-packages.v1","approved":True,
                    "inventoryResultSHA256":sw.sha256(result),"packages":["example.test/mod/a"],
                    "review":{"path":str(review),"sha256":sw.sha256(review)},
                    "inventoryStart":{"path":str(start),"sha256":sw.sha256(start)},
                    "inventoryStdout":{"path":str(stdout),"sha256":sw.sha256(stdout)},
                    "inventoryProposal":{"path":str(proposal),"sha256":sw.sha256(proposal)}}))
                return artifact
            result.write_text(json.dumps({"timedOut":False,"exit":1,"stdout":{"sha256":sw.sha256(stdout)}}))
            with self.assertRaises(RuntimeError):
                sw.package_artifact(write_artifact(), result, root, candidate, proof)
            result.write_text(json.dumps({"timedOut":False,"exit":0,"stdout":{"sha256":sw.sha256(stdout)}}))
            stdout.write_bytes(b"example.test/mod/b\n")
            with self.assertRaises(RuntimeError):
                sw.package_artifact(write_artifact(), result, root, candidate, proof)
            stdout.write_bytes(b"example.test/mod/a\n")
            with self.assertRaises(RuntimeError):
                sw.package_artifact(write_artifact(), result, root, "d" * 64, proof)
            with self.assertRaises(RuntimeError):
                sw.package_artifact(write_artifact(), result, root, candidate, {"head":"wrong","status":""})

    def test_full_argv_expands_only_reviewed_literals_and_and111_stays_external(self):
        argvs, cwd = sw.command_argv("go-full", {"cwd": "runnerRepo",
            "argv": ["go", "test", "-count=1", sw.PACKAGE_MARKER]}, Path("/tmp/out"),
            ["example.test/mod/a", "example.test/mod/b"])
        self.assertEqual(cwd, "runnerRepo")
        self.assertEqual(argvs[0][-2:], ["example.test/mod/a", "example.test/mod/b"])
        with self.assertRaises(RuntimeError):
            sw.command_argv("go-full", {"cwd": "runnerRepo",
                "argv": ["go", "test", "-count=1", sw.PACKAGE_MARKER]}, Path("/tmp/out"), None)
        inventory_argv, _ = sw.command_argv("go-inventory",
            {"cwd": "runnerRepo", "argv": ["go", "list", "./..."]}, Path("/tmp/out"), None)
        self.assertEqual(inventory_argv, [["go", "list", "./..."]])
        rows = sw.inventory_rows({"rows": {"AND-111": {"commands": ["and-111-compile"],
            "separateEvidence": ["shutdown proof"]}}}, {}, None)
        self.assertFalse(rows["AND-111"]["satisfiedHere"])
        self.assertEqual(rows["AND-111"]["missingCommands"], ["and-111-compile"])

    def test_evidence_manifest_hashes_metadata_and_streams(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw); (root / "command").mkdir()
            (root / "command" / "start.json").write_text("{}\n")
            (root / "command" / "stdout.bin").write_bytes(b"stream")
            files = sw.evidence_files(root)
            self.assertEqual([x["path"] for x in files], ["command/start.json", "command/stdout.bin"])
            self.assertTrue(all(len(x["sha256"]) == 64 for x in files))

    def test_output_is_absolute_and_excludes_frozen_descendants(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw).resolve(); frozen = root / "repo"; frozen.mkdir()
            output = sw.resolve_output(root / "evidence", [frozen])
            self.assertTrue(output.is_absolute())
            with self.assertRaises(RuntimeError):
                sw.resolve_output(frozen / "ignored" / "evidence", [frozen])

    def test_postflight_closes_on_home_entry_and_persists_drift_observation(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw); grantiva = root / "grantiva"; maestro = root / "maestro"
            command_out = root / "command"; command_out.mkdir()
            command_result = sw.run_bounded(["python3", "-c",
                "import os,pathlib; pathlib.Path(os.environ['GRANTIVA_RUNNER_HOME'],'created-directory').mkdir(parents=True)"],
                root, {"GRANTIVA_RUNNER_HOME":str(grantiva)}, 2, command_out)
            baseline = {"realpath":"/fake/repo","head":sw.CLI_SHA,"status":"",
                        "trackedFileCount":1,"trackedTreeSHA256":"before","trackedEntryIssues":[]}
            observed = {**baseline, "head":"changed", "status":" M source.swift\n",
                        "trackedTreeSHA256":"after"}
            contents, reasons = sw.evaluate_postflight(
                [command_result], [0], observed, sw.CLI_SHA, baseline,
                {"GRANTIVA_API_KEY":"unset", "GRANTIVA_RUNNER_HOME":str(grantiva),
                 "MAESTRO_RUNNER_HOME":str(maestro)})
            self.assertIn("head-mismatch", reasons)
            self.assertIn("dirty-status", reasons)
            self.assertIn("source-proof-drift", reasons)
            self.assertIn("nonempty-GRANTIVA_RUNNER_HOME", reasons)
            self.assertEqual(contents["GRANTIVA_RUNNER_HOME"]["entries"],
                             [{"path":"created-directory","kind":"directory"}])

    def test_postflight_rejects_file_and_dangling_symlink_home_roots(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw); proof = {"realpath":"/fake/repo","head":sw.CLI_SHA,"status":"",
                "trackedFileCount":1,"trackedTreeSHA256":"same","trackedEntryIssues":[]}
            for name, script in (("file", "import os,pathlib; pathlib.Path(os.environ['GRANTIVA_RUNNER_HOME']).write_text('x')"),
                                 ("dangling", "import os,pathlib; pathlib.Path(os.environ['GRANTIVA_RUNNER_HOME']).symlink_to('missing-target')")):
                home = root / name; out = root / (name + "-command"); out.mkdir()
                result = sw.run_bounded(["python3", "-c", script], root,
                                        {"GRANTIVA_RUNNER_HOME":str(home)}, 2, out)
                contents, reasons = sw.evaluate_postflight([result], [0], proof, sw.CLI_SHA, proof,
                    {"GRANTIVA_RUNNER_HOME":str(home), "MAESTRO_RUNNER_HOME":str(root / (name + "-absent"))})
                self.assertIn("invalid-root-GRANTIVA_RUNNER_HOME", reasons)
                self.assertEqual(contents["GRANTIVA_RUNNER_HOME"]["rootKind"],
                                 "file" if name == "file" else "symlink")

    def test_gate_accepts_markdown_review_and_binds_provision_ownership(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw); candidate = root / "candidate.json"; gate = root / "gate.json"
            review = root / "review.md"; cleanup = root / "cleanup.json"
            provision = root / "provision.json"; ownership_path = root / "ownership.json"
            shutdown = root / "shutdown.json"
            candidate.write_text('{"schema":"grantiva.task9.candidate.v1"}\n')
            review.write_text("# approved static review\n"); cleanup.write_text('{"passed":true}\n')
            ownership = {"schema":"grantiva.task9.primary-ownership.v1",
                "candidateManifestSHA256":sw.sha256(candidate), "gateEvidence":str(gate),
                "devices":{"android":{"owned":True,"name":"cov4-android","avd":"cov4-android",
                    "id":"emulator-5584","ownedPIDs":[123],
                    "launch":{"pid":123,"argv":["emulator","-avd","cov4-android","-port","5584"]}}}}
            gate.write_text(json.dumps({"schema":"grantiva.task8.zero-gate.v1","passed":True,
                "candidateManifestSHA256":sw.sha256(candidate),
                "review":{"path":str(review),"sha256":sw.sha256(review)},
                "cleanup":{"path":str(cleanup),"sha256":sw.sha256(cleanup)}}))
            ownership_path.write_text(json.dumps(ownership))
            provision.write_text(json.dumps({"schema":"grantiva.task9.primary-provision.v1","passed":True,
                "candidateManifestSHA256":sw.sha256(candidate),"gateEvidenceSHA256":sw.sha256(gate),
                "ownership":ownership}))
            shutdown.write_text(json.dumps({"schema":"grantiva.task9.android-shutdown-transition.v1",
                "passed":True,"state":"created-shutdown","candidateManifestSHA256":sw.sha256(candidate),
                "primaryProvisionSHA256":sw.sha256(provision),"gateEvidenceSHA256":sw.sha256(gate),
                "allocation":{"avd":"cov4-android","serial":"emulator-5584","pid":123},
                "ownership":{"path":str(ownership_path),"sha256":sw.sha256(ownership_path)}}))
            bindings = sw.validate_gate(candidate, json.loads(candidate.read_text()), gate, provision, shutdown)
            self.assertEqual(bindings["ownershipSHA256"], sw.sha256(ownership_path))
            wrong = json.loads(ownership_path.read_text()); wrong["devices"]["android"]["ownedPIDs"] = [456]
            ownership_path.write_text(json.dumps(wrong))
            doc = json.loads(shutdown.read_text()); doc["ownership"]["sha256"] = sw.sha256(ownership_path)
            shutdown.write_text(json.dumps(doc))
            with self.assertRaises(RuntimeError):
                sw.validate_gate(candidate, json.loads(candidate.read_text()), gate, provision, shutdown)


if __name__ == "__main__":
    unittest.main()
