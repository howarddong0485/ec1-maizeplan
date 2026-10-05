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

## Mobile app verification — completed 2026-09-26

Mobile-app workflow verification is complete. Device model and operating-system version are intentionally omitted. The command, build, and browser checks below identify their execution surfaces separately; this record does not imply testing every mobile platform or packaging route.

Recommended reproduction route: **compatible Expo Go**, as documented in README. Run the shared planning server, start the Jac mobile development bundle from a separate source copy, open it in an Expo Go client compatible with the generated SDK, and set MaizePlan's Server URL to the planning server's LAN address and API port. Sign in with the same account as the web and CLI.

## One-click sample and short demo — 2026-10-05

Added `load_sample` on the authenticated backend, **Load sample week** on web/mobile, and `jac run cli sample`. The web includes an expandable three-minute walkthrough with links to study recording and weekly planning; README includes the timed steps and an actual UI screenshot.

This run used Jac 0.37.21 and an isolated source copy with a separate database on web/API ports 8150/8151; the React Native Web preview used 8152. It reused the existing Python environment. These checks cover the sample extension; the earlier clean GitHub checkout and native bundle results below remain dated baseline evidence.

| Check | Measured result |
|---|---|
| Compiler and scheduler | All 3 app roots passed `jac check` with warnings; 12 scheduler tests passed |
| Builds | `jac build web` and `jac build --platform web mobile` passed |
| Sample API/CLI | `scripts/sample_test.py` passed: CLI seed, account isolation, rejected unauthenticated/invalid-date requests, correct weekday rotation including Sunday→Monday, and 65→40-minute deadline shortfall |
| Existing regressions | `smoke_test.py`, `feature_test.py` and `lifecycle_test.py` passed against the real isolated backend |
| Existing data | Accounts with archived tasks or saved capacity rejected seeding with their snapshots unchanged. Repeating a successful seed after study, archive and capacity changes preserved all data and the original sample date/ID |
| Web interaction | New account → sample button → one 90-minute task; Progress automatically loaded 25/120/0/0/0/0/0. Walkthrough links navigated to the controls. Weekly plan showed 65 minutes short; recording 25 and replanning showed 40 |
| Mobile interaction | React Native Web sample button created the same scenario and opened Progress with the saved capacities loaded |

Run `python3 scripts/sample_test.py` with the development server running, or pass `--server URL`. It creates four disposable accounts without touching other accounts. Sample dates come from the requesting client; a replay retains the initial date. Repeat-request checks cover sequential retries, not simultaneous multi-client seeding. New sample-button interaction checks used React Native Web; this run did not repeat physical-device testing.

## Fresh GitHub checkout verification — 2026-09-26

Tested application revision: **`4903800578f6532a1514926f12d60fa1706cace9`** (`4903800`), cloned directly from `https://github.com/howarddong0485/ec1-maizeplan.git`. The checkout had an empty `git status --short` before setup and after the application checks. The September validation update changed documentation only; the October sample extension is recorded separately above.

Environment: **Jac 0.37.21**, Apple Silicon macOS, **Homebrew Python 3.14.7**. The clone started without `.jac/`, `node_modules/`, `dist/`, or `.env`; a new project venv and database were created. The installed Jac executable, global toolchain/download caches, and Homebrew Python were reused. This verifies a fresh checkout on a configured development computer, not a clean operating-system installation.

| Check | Measured result |
|---|---|
| Installation | New `.jac/venv` created with Homebrew Python; `jac install` exited 0 and installed 105 npm packages |
| Default startup | Bare `jac run` started the web frontend at `http://localhost:8000` and API at `http://127.0.0.1:8001`; account creation and sign-in worked |
| Scheduler and compiler | `jac test core/planning.jac`: **12 passed**; `jac check`: **3 app roots passed**, with warning-level diagnostics |
| Production artifacts | `jac build web` produced `dist/maizeplan.jab`; `jac build --platform web mobile` produced the mobile browser bundle |
| Real API/CLI integration | All three scripts passed: `smoke_test.py`, `feature_test.py`, and `lifecycle_test.py`, using newly created disposable accounts |
| README review walkthrough | All six steps passed across web, React Native Web, and CLI; exact observations are recorded below |
| Process restart | After Ctrl+C and a new `jac run`, all three `--verify-restart-state` checks passed: authentication, task/history snapshots, saved capacity, archives, audit revisions and retry identity persisted |
| Fresh mobile setup | A source-only helper copy ran `jac setup mobile` successfully and installed 484 Expo packages |
| Expo development startup | With the temporary configuration adjustment in README step 3, the mobile compiler, Metro on 8081 and API-only helper on 8143 started successfully |
| Native JavaScript bundles | Metro returned HTTP 200 for Android (6,678,546 bytes; 1,098 modules) and iOS (6,670,431 bytes; 1,099 modules). Both contained the MaizePlan screens, including study recording, corrections and saved capacity. These are bundle checks, not APK/IPA builds or device interaction checks |

**Review walkthrough observations.** A new account contained only **Finish EECS 449 report**, due 2026-09-26 with 90 minutes remaining. Web saved capacities of 25 minutes today, 120 tomorrow and zero on the other five days. Mobile Progress loaded that routine. The initial forecast fit all 90 focus minutes across the horizon but reported a **65-minute deadline shortfall**. Recording 25 through React Native Web gave **65 remaining / 25 recorded**; web refresh cleared the old forecast and retained the capacities, and regeneration gave a **40-minute shortfall**. CLI correction to 10 gave **80 remaining / 10 recorded**. Web undo returned remaining effort to **90**; restoring 25 returned it to **65**, with the original entry and all three revisions visible. Web archive removed the task from `cli list --all` while `cli list --archived` retained it. Mobile refresh showed no active tasks; restoring from its archive made web refresh show the same 65-minute task again, with history intact.

The mobile browser preview ran on 8142 against the shared API on 8001. The separate Expo helper used 8143 to keep its database/session separate. The helper source copy's only configuration change was `platform = "web"` under `[apps.mobile]`, paired with the explicit `--platform android` development argument. Without this adjustment, Jac 0.37.21's spawned helper incorrectly attempted an Android native build and reached SDK license setup; that attempt was stopped. The adjusted launch served both native JavaScript bundles without that build step. README now includes the tested adjustment.

To reproduce the fresh-checkout checks at the recorded revision:

```bash
git clone https://github.com/howarddong0485/ec1-maizeplan.git maizeplan-clean
cd maizeplan-clean
# Exact application revision recorded above:
git checkout 4903800578f6532a1514926f12d60fa1706cace9
"$(brew --prefix python@3.14)/bin/python3.14" -m venv .jac/venv
jac install
jac test core/planning.jac
jac check
jac build web
jac build --platform web mobile
jac run
```

In another terminal in the same checkout:

```bash
python3 scripts/smoke_test.py --write-restart-state .jac/clean-smoke.json
python3 scripts/feature_test.py --write-restart-state .jac/clean-features.json
python3 scripts/lifecycle_test.py --write-restart-state .jac/clean-lifecycle.json
# Stop the server with Ctrl+C, then start a new jac run in its terminal.
python3 scripts/smoke_test.py --verify-restart-state .jac/clean-smoke.json
python3 scripts/feature_test.py --verify-restart-state .jac/clean-features.json
python3 scripts/lifecycle_test.py --verify-restart-state .jac/clean-lifecycle.json
```

For Expo startup, use [README's mobile steps](README.md#3-start-the-mobile-development-bundle--terminal-b), including the temporary helper configuration. The local bundle check used `JAC_RN_DEV_HOST=127.0.0.1` and helper port 8143; a phone needs the computer's reachable LAN address. The script-generated state files contain disposable credentials and remain under ignored `.jac/`.

## Capacity, study revisions and archives — 2026-09-26

This earlier regression run used Jac 0.37.21, an isolated source copy with an existing disposable test database, web/API ports 8120/8121, and the rebuilt React Native Web preview on 8122. Existing project data was not reset. The fresh-checkout run above subsequently repeated the integration and restart checks with a new database.

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

The retry tests establish sequential replay behavior, including after restart, rather than arbitrary concurrent-client guarantees. Forecasts remain non-mutating and are cleared when tasks/history reload; capacity edits are persisted only with **Save weekly capacity**.

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

Retry tests cover sequential retries and retries after restart; they do not establish concurrent multi-client transaction guarantees. The mobile interaction measurements in this historical table cover the browser-rendered mobile source; the completed mobile-app verification is recorded above.

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

The server process was stopped and restarted; this was not simply a browser refresh. This original source-copy test reused the installed compiler/toolchain cache but had a fresh project venv and no copied `.jac/data`. It did not test a Git clone or a clean operating-system installation. The newer **Fresh GitHub checkout verification** section records the subsequent clone-based check on Jac 0.37.21.

## Test coverage

Mobile-app workflow verification is complete, as recorded above. The detailed browser interaction measurements use the compiled **React Native Web** version of the Jac mobile source; the original run used port 8010 against the API on 8001. The latest Expo checks compile and serve native Android/iOS JavaScript bundles. Each result applies to its stated surface; the bundle checks do not establish physical-device execution on both platforms or coverage of all simulator configurations.

Signed APK/IPA distribution, EAS cloud builds and store publication are separate packaging options, not artifacts included with this source delivery. GitHub/Canvas submission is outside these runtime test results.

## Environment notes

**Python setup.** The Jac-bundled Python's `ensurepip` failed with a `pyexpat` dynamic-library error: `symbol not found in flat namespace '_XML_SetAllocTrackerActivationThreshold'`. Creating `.jac/venv` with Homebrew Python 3.14 resolved dependency installation. The previous venv was preserved and existing task data was retained. README includes the reproducible setup.

**Compiler diagnostics.** The workspace check exits successfully with warnings at dynamic JSON/JS boundaries. During web packaging, some server planning helpers fell back from native lowering to Python; the web artifact was produced successfully.
