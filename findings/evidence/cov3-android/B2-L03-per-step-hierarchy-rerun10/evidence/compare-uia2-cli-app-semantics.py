#!/usr/bin/env python3
"""Compare meaningful app nodes in direct UIA2 and Grantiva CLI XML dumps.

Android UIA2 bounds are physical pixels. ``--density-dpi`` documents the
device density and converts both inputs to dp before comparison; it does not
assume that the CLI has already converted the XML.  The default tolerance of
1.25 dp covers integer-pixel serialization at 420 dpi (2.625 px/dp) without
masking a meaningful layout shift.
"""
import argparse, json, re
from collections import Counter
from pathlib import Path
import xml.etree.ElementTree as ET

BOUNDS = re.compile(r"\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]")
FRAME = re.compile(r"(?:x[:=]\s*)?(-?\d+(?:\.\d+)?)[, ]+(?:y[:=]\s*)?(-?\d+(?:\.\d+)?)[, ]+(?:width[:=]\s*)?(-?\d+(?:\.\d+)?)[, ]+(?:height[:=]\s*)?(-?\d+(?:\.\d+)?)")

def frame(attrs, scale):
    if attrs.get("bounds"):
        m = BOUNDS.fullmatch(attrs["bounds"])
        if m:
            x1,y1,x2,y2 = map(float,m.groups())
            return tuple(v/scale for v in (x1,y1,x2-x1,y2-y1))
    if attrs.get("frame"):
        m = FRAME.search(attrs["frame"])
        if m: return tuple(map(float,m.groups()))
    keys=("x","y","width","height")
    if all(k in attrs for k in keys): return tuple(float(attrs[k]) for k in keys)
    return None

def nodes(path, package, scale):
    root=ET.parse(path).getroot(); out=[]
    for e in root.iter():
        a=e.attrib
        if a.get("package") != package: continue
        klass=a.get("class") or e.tag
        ident=a.get("resource-id") or a.get("identifier") or ""
        labels=tuple(sorted(set(filter(None,(a.get("text"),a.get("content-desc"),a.get("label"),a.get("name"),a.get("value"))))))
        # Exclude anonymous layout wrappers. They are transport representation,
        # not semantic UI, and legitimately differ between serializers.
        if not ident and not labels: continue
        f=frame(a,scale)
        if f is None: continue
        out.append({"class":klass,"id":ident,"labels":labels,"frameDp":f})
    if not out: raise AssertionError(f"no meaningful {package} nodes in {path}")
    return out

def same_identity(a,b): return (a["class"],a["id"],a["labels"]) == (b["class"],b["id"],b["labels"])
def delta(a,b): return max(abs(x-y) for x,y in zip(a["frameDp"],b["frameDp"]))

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("direct_xml",type=Path); ap.add_argument("cli_xml",type=Path)
    ap.add_argument("--package",required=True); ap.add_argument("--density-dpi",type=float,required=True)
    ap.add_argument("--tolerance-dp",type=float,default=1.25); ap.add_argument("--output",type=Path,required=True)
    ns=ap.parse_args(); scale=ns.density_dpi/160.0
    direct=nodes(ns.direct_xml,ns.package,scale); cli=nodes(ns.cli_xml,ns.package,scale)
    unused=list(range(len(cli))); matches=[]; missing=[]
    for a in direct:
        candidates=[i for i in unused if same_identity(a,cli[i])]
        if not candidates: missing.append(a); continue
        i=min(candidates,key=lambda j:delta(a,cli[j])); d=delta(a,cli[i])
        if d > ns.tolerance_dp: missing.append({**a,"nearestFrameDp":cli[i]["frameDp"],"maxDeltaDp":d}); continue
        unused.remove(i); matches.append({"identity":[a["class"],a["id"],list(a["labels"])],"directFrameDp":a["frameDp"],"cliFrameDp":cli[i]["frameDp"],"maxDeltaDp":d})
    result={"package":ns.package,"densityDpi":ns.density_dpi,"pixelsPerDp":scale,
      "toleranceDp":ns.tolerance_dp,"mapping":{"class":"class attribute or XML tag","id":"resource-id or identifier","labels":"deduplicated nonempty text/content-desc/label/name/value","frame":"UIA2 bounds pixels divided by densityDpi/160; CLI frame fields are dp"},
      "directMeaningfulCount":len(direct),"cliMeaningfulCount":len(cli),"matchedCount":len(matches),
      "missingFromCLI":missing,"extraInCLI":[cli[i] for i in unused],"matches":matches}
    result["passed"] = not missing and not unused and bool(matches)
    ns.output.write_text(json.dumps(result,indent=2)+"\n")
    if not result["passed"]: raise SystemExit(1)
if __name__ == "__main__": main()
