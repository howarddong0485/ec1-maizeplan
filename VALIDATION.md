# MaizePlan — implementation and validation

MaizePlan delivers four Jac components: a persistent planning server, a web frontend, a MobUI / React Native mobile client, and a CLI. This record describes the implemented functionality, measured test results, and environment-specific build behavior. Launch and phone-use instructions are in [README.md](README.md).

## Delivered components

| Component | Implemented functionality |
|---|---|
| Server | Authenticated task creation/editing, completion/reopening, per-account graph storage, input validation, deterministic focus planning |
| Web | Account access, task capture/editing, search and filters, summary counts, focus plans and refresh |
| Mobile | Jac MobUI Tasks, Add and Focus screens, shared authentication/API transport, completion/reopening and refresh |
| CLI | Registration/login, capture, listing/filtering, completion/reopening, planning, JSON output and local session management |
| Documentation and tests | Setup and launch instructions, phone runtime options, integration script, restart-state checks and scheduler tests |

## Verified results

Test environment: Apple Silicon macOS; Jac 0.37.17; project venv created with Homebrew Python 3.14.7. Runtime tests were performed on 2026-09-15. Documentation revised 2026-09-17.

| Check | Result |
|---|---|
| Project dependency installation | Passed with the documented Homebrew-backed venv |
| Scheduler unit tests | 6 passed: empty plan, ordering, partial allocations, completed-task exclusion, invalid input and budget/break boundaries |
| Workspace check | 3 app roots passed, exit 0; warning-level dynamic-type, JSX and JS interop diagnostics |
| Default launch configuration | Web is the default app; frontend and API start together |
| Web bundle | `jac build web` passed and produced `dist/maizeplan.jab` |
| Mobile browser bundle | `jac build --platform web mobile` passed |
| Expo scaffold | `jac setup mobile` passed; Expo/React Native dependencies installed |
| API authentication and validation | Registration/login passed; anonymous listing and invalid dates rejected |
| Account isolation | Second account cannot list, complete or edit the first account's task |
| CLI integration | Capture, listing, completion/reopening, server edits and exact CLI/API plan equality passed |
| Web interaction | Login, task creation, estimate editing, refresh and focus planning passed |
| Mobile UI via React Native Web | Login, shared task display, completion, capture and focus planning passed |
| Cross-interface synchronization | Web, mobile browser UI and CLI read and modify the same backend tasks |
| Restart persistence | Authentication, task ID, edited fields and completion state survived a graceful backend process restart |
| Clean source-copy setup | Installation, frontend/API startup and expanded integration passed without copied project data or dependencies |

For the cross-interface scenario, the web created a task and changed its estimate from 60 to 75 minutes. The mobile browser UI displayed the edit and marked the task complete; refreshing the web showed that completion. The CLI reopened it. Both UIs produced a plan containing 75 focus minutes and 10 break minutes. A task captured in the mobile UI also appeared on the web.

## Reproduce the checks

From the repository root:

```bash
jac test core/planning.jac
jac check
jac build web
jac build --platform web mobile
jac run
```

With the server running, use another terminal in the same directory:

```bash
python3 scripts/smoke_test.py --write-restart-state .jac/restart-check.json
# Stop the server with Ctrl+C, then start it again with jac run.
python3 scripts/smoke_test.py --verify-restart-state .jac/restart-check.json
```

The integration script creates two disposable accounts and two tasks. It checks authentication, isolation, validation, edits, CLI capture/synchronization and matching plans. It leaves the test records in the development database and does not alter existing users' tasks. Restart state contains a disposable token and expected task snapshot, stored with owner-only permissions under ignored `.jac/`.

The isolated source-copy test used web/API ports 8020/8021 so the original app could keep running on 8000/8001:

```bash
jac run --port 8020 --api-port 8021
# Another terminal in the isolated source copy:
python3 scripts/smoke_test.py --server http://127.0.0.1:8021 --write-restart-state .jac/restart-check.json
# Stop and restart the isolated server before this command:
python3 scripts/smoke_test.py --server http://127.0.0.1:8021 --verify-restart-state .jac/restart-check.json
```

The server process was stopped and restarted; this was not simply a browser refresh. The source-copy test reused the installed compiler/toolchain cache but had a fresh project venv and no copied `.jac/data`. It did not test a Git clone or a clean operating-system installation.

## Test coverage

Mobile interaction results refer to the compiled **React Native Web** version of the Jac mobile source, served on port 8010 against the original API on 8001. Physical iOS/Android devices, simulators, phone LAN connectivity, and offline/reconnect behavior were not exercised. Phone instructions document the runtime workflow; they are not additional test pass results. No further local native-device validation was performed for the documentation delivery.

Signed APK/IPA distribution, EAS cloud builds and store publication are separate packaging options, not artifacts included with this source delivery. GitHub/Canvas submission is outside these runtime test results.

## Environment and packaging notes

**Python setup.** The Jac-bundled Python's `ensurepip` failed with a `pyexpat` dynamic-library error: `symbol not found in flat namespace '_XML_SetAllocTrackerActivationThreshold'`. Creating `.jac/venv` with Homebrew Python 3.14 resolved dependency installation. The previous venv was preserved and existing task data was retained. README includes the reproducible setup.

**Compiler diagnostics.** The workspace check exits successfully with warnings at dynamic JSON/JS boundaries. During web packaging, some server planning helpers fell back from native lowering to Python; the web artifact was produced successfully.

**Optional local iOS packaging.** Jac/native module compilation passed, but Expo prebuild failed while parsing the generated Xcode project:

```text
SyntaxError: [ios.xcodeproj]: withIosXcodeprojBaseMod:
Expected end of input but "\0" found.
```

The generated `project.pbxproj` contained 14,848 null bytes in a 31,949-byte file. The generated-code check also warned about web-only globals and an unmapped `<pre>`. This local packaging route has no successful artifact in the record; no workaround was applied to generated files or the compiler cache. The machine had Apple Command Line Tools, not full Xcode. Local diagnostics are in ignored `.jac/ios-build-validation.log` when retained.

This packaging attempt is distinct from Expo Go development, which loads the mobile bundle without building a standalone iOS application. The current scaffold uses Expo SDK 57; a compatible phone client or separately configured development/standalone build is required, as described in README.
