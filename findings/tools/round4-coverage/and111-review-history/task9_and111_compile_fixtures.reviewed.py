#!/usr/bin/env python3
import copy, importlib.util, tempfile, unittest
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
                before=m.scratch_state(inputs); apk=m.SCRATCH/"app/build/outputs/apk/free/debug/app.apk"; apk.parent.mkdir(parents=True); apk.write_bytes(b"apk")
                after=m.scratch_state(inputs); base=self.state(before); changed=copy.deepcopy(base); changed["scratch"]=after
                self.assertEqual(m.validate_transition(base,changed)[0]["path"],"app/build/outputs/apk/free/debug/app.apk")
                (m.SCRATCH/"unexpected.txt").write_text("bad"); changed["scratch"]=m.scratch_state(inputs)
                with self.assertRaises(RuntimeError): m.validate_transition(base,changed)
            finally: m.SCRATCH=old

    def state(self,scratch):
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

if __name__=="__main__": unittest.main()
