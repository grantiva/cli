# Active round-3 evidence provenance

These top-level groups existed before the invalid round-2 import and are the only recovered groups eligible for round-3 grading: `FLOWS-26`, `FLOWS-27`, `IOS-001`, `IOS-002`, `IOS-003`, `IOS-004`, `IOS-009`, `IOS-010`, `IOS-011`, `IOS-012`, `IOS-013`, `IOS-019`, `IOS-117`, `IOS-118`, `IOS-119`, `IOS-120`, `IOS-151`, `IOS-239@27.0`, `STEP1`, and `STEP2`.

These groups were created after recovery against the round-3 binary: `B3-L10`, `B3-L13`, `B3-L19`, `B3-L21`, `B3-L39`, `B3-L43`, `B3-L60`, `N3-05`, `N3-07`, and `N3-14`.

The pre-import `find` inventory captured the exact files in the recovered groups. Round-2 files added later inside an existing directory are excluded. The import used `rsync --ignore-existing`, so original files were not replaced.
