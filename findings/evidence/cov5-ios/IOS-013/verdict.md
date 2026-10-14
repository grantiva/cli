# IOS-013 candidate4 clause assessment

Verdict: **pass**.

Original attempt is retained as a fixture mismatch because IOS-011 had left the same name. Corrected adjacent capture proves the name absent before invocation, exits 1 after configured 5 seconds at 1/1, and proves no named device or residue after. Current `SimulatorManager.swift:236–285` creates and registers before the capacity wait and removes the created device in the catch path. The before/after capture proves the externally observable no-residue result; no transient UUID was observed, so none is claimed.

Candidate identity, exact argv/cwd/environment, timestamps, exits, raw streams, and before/after inventories are retained adjacent to this verdict.
