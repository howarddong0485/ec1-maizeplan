# MaizePlan — implementation and validation

MaizePlan delivers four Jac components: a persistent planning server, a web frontend, a MobUI / React Native mobile client, and a CLI. This record describes the implemented functionality, measured test results, and environment-specific build behavior. Launch and phone-use instructions are in [README.md](README.md).

## Delivered components

| Component | Implemented functionality |
|---|---|
| Server | Authenticated task creation/editing, completion/reopening, per-account graph storage, input validation, study sessions with automatic remaining-effort updates, daily/multi-day planning |
| Web | Account access, task capture/editing, search and filters, summary counts, study history, daily/weekly plans and refresh |
| Mobile | Jac MobUI Tasks, Add, Focus and Progress screens, shared authentication/API transport, completion/reopening, study records, weekly plans and refresh |
| CLI | Registration/login, capture, listing/filtering, completion/reopening, study/history, daily/multi-day planning, JSON output and local session management |
| Documentation and tests | Setup and launch instructions, phone runtime options, integration script, restart-state checks and scheduler tests |

## Feature validation — 2026-09-25

Current compiler: **Jac 0.37.21**, pinned in `jac.toml`. Generic type annotations were updated for this compiler. The earlier baseline below records the original 0.37.17 run rather than implying a fresh installation was repeated.

| Check | Measured result |
|---|---|
| Scheduler unit tests | 11 passed, including multi-day allocation, daily break reset, days off, deadline shortfalls, overdue work, year rollover, validation, ordering and source-task immutability |
| Three app roots | Type checking passed with warning-level interop diagnostics |
| Current web/mobile browser builds | Both passed: `jac build web` produced `dist/maizeplan.jab`; `jac build --platform web mobile` produced the React Native Web bundle |
| Original API/CLI regression script | Passed on the current server/compiler |
| New API/CLI feature script | Passed: study deduction, auto-completion at zero, actual-versus-credited minutes, repeat-request handling, mismatched request rejection, authentication, account isolation, invalid inputs and exact CLI/API weekly equality |
| Web interaction | Recording 25 minutes changed a 90-minute task to 65; history showed 25. A 25-minute first day and 120-minute second day produced a 40-minute deadline shortfall despite fitting all work across both days |
| Mobile React Native Web interaction | Same account showed 65 remaining; recording 15 changed it to 50 and history totaled 40. The same capacities produced 25 minutes of deadline shortfall, with late catch-up marked on day two |
| Cross-interface progress | After restarting and signing back in, the web showed the mobile-updated 50 minutes remaining and shared history totaling 40 minutes |
| Backend process restart | Passed: exact task and study-history snapshots survived a graceful stop/restart; replaying the saved request returned its existing record without another deduction |

Retry tests cover sequential retries and retries after restart; they do not establish concurrent multi-client transaction guarantees. Mobile interaction coverage remains the browser-rendered mobile source.

To reproduce the new integration and persistence checks against the local development server:

```bash
python3 scripts/feature_test.py --write-restart-state .jac/features-restart.json
# Stop and restart the server.
python3 scripts/feature_test.py --verify-restart-state .jac/features-restart.json
```

This creates disposable test accounts and leaves their data in the development database. The ignored, owner-readable state file contains a test token, task/history snapshots, and a saved retry payload.

## Original baseline results

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

Mobile interaction results refer to the compiled **React Native Web** version of the Jac mobile source, served on port 8010 against the original API on 8001. Physical iOS/Android devices and simulators were not exercised. Phone instructions document the runtime workflow; they are not additional test pass results.

Signed APK/IPA distribution, EAS cloud builds and store publication are separate packaging options, not artifacts included with this source delivery. GitHub/Canvas submission is outside these runtime test results.

## Environment notes

**Python setup.** The Jac-bundled Python's `ensurepip` failed with a `pyexpat` dynamic-library error: `symbol not found in flat namespace '_XML_SetAllocTrackerActivationThreshold'`. Creating `.jac/venv` with Homebrew Python 3.14 resolved dependency installation. The previous venv was preserved and existing task data was retained. README includes the reproducible setup.

**Compiler diagnostics.** The workspace check exits successfully with warnings at dynamic JSON/JS boundaries. During web packaging, some server planning helpers fell back from native lowering to Python; the web artifact was produced successfully.
