#!/usr/bin/env python3
import copy, importlib.util, os, tempfile, unittest
from pathlib import Path

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location("and111",HERE/"task9_and111_compile.py")
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

class Fixtures(unittest.TestCase):
    def test_bounded_command_keeps_streams_and_refuses_overwrite(self):
        with tempfile.TemporaryDirectory() as raw:
            root=Path(raw); out=root/"out"; out.mkdir()
            stdout,meta=m.run(out,"fake",["python3","-c","import sys;print('ok');print('err',file=sys.stderr)"],root,{},2)
            self.assertEqual(stdout,b"ok\n"); self.assertEqual(meta["exit"],0)
            self.assertEqual((out/"fake/stderr.bin").read_bytes(),b"err\n")
            with self.assertRaises(FileExistsError): m.run(out,"fake",["python3","-c","pass"],root,{},2)

    def test_scratch_manifest_and_generated_apk_boundary(self):
        with tempfile.TemporaryDirectory() as raw:
            old=m.SCRATCH; m.SCRATCH=Path(raw)
            try:
                (m.SCRATCH/"source.txt").write_text("source"); (m.SCRATCH/"grantiva-android.yml").write_text("emulator: cov4-android\n")
                inputs={"trackedInputs":[{"path":"android/source.txt","sourceSHA256":m.sha(m.SCRATCH/"source.txt")},
                    {"path":"android/grantiva-android.yml","sourceSHA256":"old"}],"config":{"scratchSHA256":m.sha(m.SCRATCH/"grantiva-android.yml")}}
                before=m.scratch_state(inputs); cache=m.SCRATCH/".gradle/state.bin"; cache.parent.mkdir(); cache.write_bytes(b"cache")
                apk=m.SCRATCH/"app/build/outputs/apk/free/debug/app.apk"; apk.parent.mkdir(parents=True); apk.write_bytes(b"apk")
                after=m.scratch_state(inputs); base=self.state(before); changed=copy.deepcopy(base); changed["scratch"]=after
                self.assertEqual(m.validate_transition(base,changed)[0]["path"],"app/build/outputs/apk/free/debug/app.apk")
                (m.SCRATCH/"unexpected.txt").write_text("bad"); changed["scratch"]=m.scratch_state(inputs)
                with self.assertRaises(RuntimeError): m.validate_transition(base,changed)
            finally: m.SCRATCH=old

    def state(self,scratch):
        scratch=copy.deepcopy(scratch); scratch.setdefault("unexpectedLinks",[]); scratch.setdefault("unexpectedEntries",[])
        return {"adbDevicesSHA256":"a","forwardsSHA256":"f","avds":["cov4-android"],"ownedPIDAbsent":True,
                "ownedSerialAbsent":True,"covRegistrationSHA256":"r","covConfigSHA256":"c","protectedPixelSHA256":"p",
                "ios":{"id":{"state":"Booted"}},"frozen":{"cli":"same"},"scratch":scratch}

    def test_transition_rejects_device_and_frozen_deltas(self):
        before=self.state({"tracked":{"x":"y"},"generated":[]}); after=copy.deepcopy(before)
        apk={"path":"app/build/a.apk","sha256":"x","bytes":1}; after["scratch"]["generated"]=[apk]
        self.assertEqual(m.validate_transition(before,after),[apk])
        for key,value in (("adbDevicesSHA256","changed"),("frozen",{"cli":"changed"})):
            bad=copy.deepcopy(after); bad[key]=value
            with self.assertRaises(RuntimeError): m.validate_transition(before,bad)

    def test_nonfollowing_runner_manifest_detects_symlink_retarget(self):
        with tempfile.TemporaryDirectory() as raw:
            root=Path(raw); (root/"a").mkdir(); (root/"b").mkdir(); os.symlink("a",root/"cache")
            first=m.nonfollowing_tree(root); (root/"cache").unlink(); os.symlink("b",root/"cache")
            self.assertNotEqual(first["treeSHA256"],m.nonfollowing_tree(root)["treeSHA256"])

    def test_installed_runner_preexisting_mismatch_rejected(self):
        with tempfile.TemporaryDirectory() as raw:
            runner=Path(raw)/"runner"; runner.write_bytes(b"wrong")
            with self.assertRaises(RuntimeError):
                m.installed_runner_state({"runner":{"installed":{"path":str(runner),"sha256":"0"*64}}})

    def test_output_descendant_and_dirty_scratch_rejected_preflight(self):
        with tempfile.TemporaryDirectory() as raw:
            old=(m.SCRATCH,m.RUNNER_HOME,m.CLI); root=Path(raw)
            try:
                m.SCRATCH=root/"scratch"; m.SCRATCH.mkdir(); m.RUNNER_HOME=root/"home"; m.RUNNER_HOME.mkdir()
                m.CLI=root/"cli"; m.CLI.write_bytes(b"cli")
                candidate={"cli":{"repoPath":str(root/"cli-repo"),"bundle":{"path":str(root/"bundle")}},
                    "demo":{"repoPath":str(root/"demo"),"androidAPK":{"path":str(root/"a.apk")},"iosApp":{"path":str(root/"a.app")}},
                    "runner":{"repoPath":str(root/"runner-repo"),"packaged":{"path":str(root/"packaged")},
                              "installed":{"path":str(root/"installed")}}}
                with self.assertRaises(RuntimeError): m.validate_output_path(m.RUNNER_HOME/"new",candidate)
                dirty=self.state({"tracked":{},"generated":[{"path":"build/x"}],"unexpectedLinks":[],"unexpectedEntries":[]})
                with self.assertRaises(RuntimeError): m.validate_preflight(dirty)
                dirty["scratch"]={"tracked":{},"generated":[],"unexpectedLinks":[{"path":"link"}],"unexpectedEntries":[]}
                with self.assertRaises(RuntimeError): m.validate_preflight(dirty)
            finally: m.SCRATCH,m.RUNNER_HOME,m.CLI=old

    def test_nonzero_and_timeout_results_are_returned_for_terminal_recording(self):
        with tempfile.TemporaryDirectory() as raw:
            root=Path(raw); out=root/"out"; out.mkdir()
            _,failed=m.run(out,"nonzero",["python3","-c","raise SystemExit(7)"],root,{},2,check=False)
            _,timed=m.run(out,"timeout",["python3","-c","import time; time.sleep(2)"],root,{},.02,check=False)
            self.assertEqual(failed["exit"],7); self.assertFalse(failed["timedOut"])
            self.assertTrue(timed["timedOut"]); self.assertIsNone(timed["exit"])
            before=self.state({"tracked":{"x":"y"},"generated":[]})
            after=copy.deepcopy(before); after["scratch"]["generated"]=[{"path":"app/build/a.apk","sha256":"x","bytes":1}]
            old_snapshot,old_git=m.snapshot,m.git_proof
            calls=[]
            try:
                m.snapshot=lambda *args: calls.append("snapshot") or after
                m.git_proof=lambda out,label,repo,expected,env: {"repo":str(repo),"head":expected,"status":""}
                candidate={"demo":{"sourceSHA":"d"},"cli":{"mergedSHA":"c"}}
                before_source={"demo":{"repo":"demo","head":"d","status":""},"cli":{"repo":"cli","head":"c","status":""}}
                for index,meta in enumerate((failed,timed)):
                    terminal=root/f"terminal-{index}"; terminal.mkdir()
                    self.assertIsNone(m.post_compile(terminal,meta,before,before_source,{},candidate,{},Path("demo"),Path("cli")))
                    record=m.load(terminal/"terminal-nonpass.json")
                    self.assertFalse(record["passed"]); self.assertEqual(record["firstFailure"]["stage"],"compile")
                self.assertEqual(calls,["snapshot","snapshot"])
            finally: m.snapshot,m.git_proof=old_snapshot,old_git

if __name__=="__main__": unittest.main()
