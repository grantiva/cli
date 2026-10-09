# Detect a git work tree from a subdirectory in `doctor`

Severity: ux
Platforms: cli, ios, android
Found by: AND-F22 (matrix rows AND-090; gate "Minor")
Binary: grantiva 2.0.1 (commit c8dc86d), runner 1.1.18-grantiva.7+android-drivers-2, emulator-5554 (Pixel_8_API_35, API 35)

## Expected
The Git Repository check passes anywhere inside a work tree. Source: matrix AND-090; git semantics
(`git rev-parse --is-inside-work-tree`). Mono-repos with `ios/` and `android/` subprojects are the documented layout for
`grantiva-android.yml` next to the Gradle project (docs/android.md).

## Actual
In /Users/kyle/Developer/landmarks-demo/android (work tree root: /Users/kyle/Developer/landmarks-demo):
```
  Project

    ✓ grantiva-android.yml  Found
    ● Git Repository        Not a git repository
                              Run: git init
```
Following the advice would create a nested repository.

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=qa-android
cd /Users/kyle/Developer/landmarks-demo/android
git rev-parse --show-toplevel                  # /Users/kyle/Developer/landmarks-demo
grantiva doctor --platform android | grep -A1 "Git Repository"
```

## Evidence
- findings/evidence/AND-090/doctor.txt

## Suspected cause
Sources/GrantivaCore/Doctor/DoctorRunner.swift:194-204 (`checkGitRepository`) only tests `FileManager.fileExists(".git")`
in the current directory. It also misses worktrees and submodules, where `.git` is a file (it happens to pass there).

## Acceptance criteria
- Re-running the repro: `✓ Git Repository  Detected` (optionally showing the top-level path).
- The check walks up from the cwd for a `.git` entry (directory or file) or runs `git rev-parse --is-inside-work-tree`.
- GrantivaCoreTests/DoctorTests: a temp dir `root/.git/` with cwd `root/android` passes; a dir with no ancestor `.git`
  still warns.
