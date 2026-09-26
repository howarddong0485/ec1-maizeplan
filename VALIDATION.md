# MaizePlan — implementation and validation

MaizePlan delivers four Jac components: a persistent planning server, a web frontend, a MobUI / React Native mobile client, and a CLI. This record describes the implemented functionality, measured test results, and environment-specific build behavior. Launch and phone-use instructions are in [README.md](README.md).

## Delivered components

| Component | Implemented functionality |
|---|---|
| Server | Authenticated tasks and archives, per-account graph storage, study sessions and immutable revisions, saved weekly capacity, daily/multi-day planning |
| Web | Task editing, search/filters, archive/restore, study correction/undo/restore/audit, saved capacity, workload chart and refresh |
| Mobile | Jac MobUI Tasks, Add, Focus and Progress screens, task archives, study corrections/audit, saved capacity and workload chart |
| CLI | Account/session management, task lifecycle, study/history/corrections, saved capacity, daily/multi-day plans, text workload chart and JSON output |
| Documentation and tests | Setup and launch instructions, phone runtime options, integration script, restart-state checks and scheduler tests |

## Mobile app verification - 2026-09-25

The project author confirmed successfully reproducing the mobile app workflow. Device model and operating-system version are intentionally omitted. This confirmation supplements the independently recorded React Native Web checks below; it does not claim that every mobile platform, packaging route, or regression scenario was tested.

Recommended reproduction route: **compatible Expo Go**, as documented in README. Run the shared planning server, start the Jac mobile development bundle from a separate source copy, open it in an Expo Go client compatible with the generated SDK, and set MaizePlan's Server URL to the planning server's LAN address and API port. Sign in with the same account as the web and CLI.

## Capacity, study revisions and archives — 2026-09-26

Measured using Jac 0.37.21, an isolated source copy with an existing disposable test database, web/API ports 8120/8121, and the rebuilt React Native Web preview on 8122. Existing project data was not reset. These additions were not independently executed on a native device; the author's earlier confirmation above predates this feature revision.

| Check | Measured result |
|---|---|
| Scheduler tests | 12 passed, including archived-work exclusion and per-day overdue/catch-up counts |
| Compilation and builds | `jac check`: 3 app roots passed with warnings; final `jac build web` and `jac build --platform web mobile` passed |
| Existing regressions | `scripts/smoke_test.py` and `scripts/feature_test.py` passed against the real API/CLI |
| New lifecycle integration | `scripts/lifecycle_test.py` passed: saved capacity, date rotation, correction/undo/restore, audit history, archives, validation, account isolation and CLI/API parity |
| Capacity defaults | Omitted and explicit-null budgets use the saved routine; an explicit empty list remains invalid. Wednesday correctly rotates Monday-first capacity to Wednesday-first |
| Study accounting | 90-minute task → log 25 → 65 remaining → correct to 10 → 80 → undo → 90 → restore → 80. A 100-minute log credited against 30 restores only 30 when undone |
| Manual changes and retries | Newer manual remaining estimates and explicit completions were preserved; stale versions and changed payloads sharing a request ID were rejected; identical sequential retries applied once |
| Archives | Excluded from normal lists and both planners; accessible in archive view and restorable. History retained; corrections on archived tasks kept the archive state |
| Old data | Pre-existing task and four study records loaded with the added defaults. A pre-existing record was corrected, undone and restored through the UIs |
| Web/mobile workflow | Web saved Saturday/Sunday capacities of 25/120; mobile and a later web sign-in loaded them. Both UIs mapped those values to the correct weekdays after changing the start date |
| Cross-interface revisions | Web changed a 15-minute record to 5: remaining 25 → 35, active history 65 → 55. Mobile refresh matched and cleared its old forecast; mobile undo produced 40/50, then restoring 15 returned 25/65 |
| Cross-interface archives | Web archived the task; its active count fell to zero while history remained. Mobile refresh showed no active tasks; its archive view restored the task, which web refresh counted again |
| Charts and audit UI | Web and mobile rendered focus/free capacity and late-work labels; the three-change audit showed the original and each adjustment. Desktop and 390-pixel mobile preview layouts were inspected; both browser consoles had no captured errors |
| Process restart | All three scripts' restart checks passed: task/history snapshots, archived state, saved capacity and revision history survived; replaying a saved correction made no second adjustment |

The retry tests establish sequential replay behavior, including after restart, rather than arbitrary concurrent-client guarantees. Native keyboard/scroll behavior for the new controls still needs device testing. Forecasts remain non-mutating and are cleared when tasks/history reload; capacity edits are persisted only with **Save weekly capacity**.

To reproduce the added API/CLI and restart checks:

```bash
python3 scripts/lifecycle_test.py --write-restart-state .jac/lifecycle-restart.json
# Stop and restart the same server.
python3 scripts/lifecycle_test.py --verify-restart-state .jac/lifecycle-restart.json
```

The script creates disposable accounts and keeps its token/snapshots in an ignored, owner-readable state file. For a UI demo, save a routine on web, load it in mobile Progress, correct/undo/restore a record, inspect its audit, archive/restore its task, and refresh the other interface after each change.

## Refresh consistency regression

Tasks and study history now reload together on login, after local changes, and through either refresh control. A weekly forecast is displayed only for the task snapshot it was generated from, so a later response for an older snapshot cannot restore it after a refresh. Refreshing preserves the weekly start date and daily budgets in the current Progress screen. Refresh failures remain visible as errors and do not report a successful synchronization.

Measured with Jac 0.37.21, an isolated source copy using the existing Python environment, web/API ports 8120/8121, and the rebuilt React Native Web preview on port 8122. This regression did not repeat native-device execution or a fresh-machine setup.

| Check | Measured result |
|---|---|
| Compilation | `jac check`: 3 app roots passed with warnings; `jac build web` and `jac build --platform web mobile` passed |
| Initial history | Signing in loaded a task with 65 minutes remaining and 25 recorded minutes; Progress displayed history without a separate history request from the user |
| Changes from CLI | CLI recorded 15 more minutes. Web's top-level Refresh and mobile Progress's Refresh each showed 50 remaining and 40 total recorded minutes |
| Forecast invalidation | Web's old daily and weekly plans disappeared; mobile Progress's old weekly plan disappeared. Both retained daily budgets beginning with 25 and 120 minutes |
| Regeneration | Both weekly plans used 50 remaining minutes and reported a 25-minute deadline shortfall, replacing the previous 65-minute plan and 40-minute shortfall |
| Local study recording | Web recorded 10 more minutes and immediately showed 40 remaining / 50 recorded. Mobile then recorded 15 and showed 25 remaining / 65 recorded. Each cleared its previous forecast |
| Failed refresh | After stopping the test server, web and mobile refresh displayed a fetch error and cleared the preceding refresh-success message |

To repeat the refresh regression:

1. Create a task due today with 90 minutes remaining and record 25 minutes. Sign into web and mobile with the same account.
2. Generate weekly plans with 25 minutes today and 120 tomorrow; also generate a daily plan on the web.
3. Record 15 minutes through the CLI, then use web **Refresh all devices’ changes** and mobile Progress **Refresh tasks & study history**.
4. Verify 50 remaining minutes, 40 total recorded minutes, cleared forecasts, and preserved capacities. Regenerate the weekly plans and verify a 25-minute deadline shortfall.

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

Retry tests cover sequential retries and retries after restart; they do not establish concurrent multi-client transaction guarantees. The mobile interaction measurements in this table cover the browser-rendered mobile source; the author's mobile-app confirmation is recorded separately above.

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

The automated and agent-observed mobile interaction results refer to the compiled **React Native Web** version of the Jac mobile source. The original run used port 8010 against the API on 8001. The project author has additionally confirmed successful reproduction in the mobile app, as recorded above. Native-device execution was not independently repeated by the agent, and no claim is made that both iOS and Android or all simulator configurations were tested.

Signed APK/IPA distribution, EAS cloud builds and store publication are separate packaging options, not artifacts included with this source delivery. GitHub/Canvas submission is outside these runtime test results.

## Environment notes

**Python setup.** The Jac-bundled Python's `ensurepip` failed with a `pyexpat` dynamic-library error: `symbol not found in flat namespace '_XML_SetAllocTrackerActivationThreshold'`. Creating `.jac/venv` with Homebrew Python 3.14 resolved dependency installation. The previous venv was preserved and existing task data was retained. README includes the reproducible setup.

**Compiler diagnostics.** The workspace check exits successfully with warnings at dynamic JSON/JS boundaries. During web packaging, some server planning helpers fell back from native lowering to Python; the web artifact was produced successfully.
