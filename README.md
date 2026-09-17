# MaizePlan

**Student:** Gehao Dong / dgehao  
**UMID:** 62168169  
**Course:** EECS 449 / CSE449-F26 — Assignment 1  
**Delivery:** Jac server, web frontend, mobile client, CLI, automated tests, and setup documentation. See [VALIDATION.md](VALIDATION.md) for measured results and test coverage.

MaizePlan is a personal coursework planner written in Jac. It turns assignment deadlines and estimated effort into a realistic, time-budgeted study plan. The web, native mobile, and terminal interfaces all use the same authenticated Jac server and persistent task graph.

## Features

- Add tasks with a course, deadline, priority, and estimated remaining minutes.
- Edit tasks on the web; mark complete or reopen from web, mobile, or CLI.
- Web search, open/completed filters, and overdue/completion counts.
- A transparent focus planner: earliest deadline first, priority as a tie-breaker, up to 25 minutes of work followed by a 5-minute break.
- The time budget **includes breaks**. Large tasks can receive partial blocks. Due/overdue work that cannot fit is explicitly reported.
- Native mobile screens use Jac MobUI / React Native, not an HTML webview.
- Account-isolated graph persistence; anonymous access to planning endpoints is not allowed.
- No LLM key, paid API, or external calendar required.

The planner is a suggestion rather than a calendar booking. Changing the planning day changes overdue reporting, not which tasks are eligible: all open tasks may be scheduled. It does not track actual study time, send notifications, run offline, or decrement remaining minutes automatically. Edit estimates to reflect progress.

## Prerequisites

1. Install **Jac 0.37.17** from the [official repository](https://github.com/jaseci-labs/jac/releases/tag/v0.37.17). Use the release appropriate for your operating system and CPU. Do not replace it with an older PyPI `jaclang` installation; this project uses the current workspace/MobUI toolchain.
2. Install VS Code and its Jac extension, as recommended by the course.
3. Have an internet connection for the first dependency and embedded database downloads. Jac supplies its own Python/Bun toolchain. The optional integration script uses system Python 3.10+.
4. Run Jac as your normal desktop user, **not with sudo/root**. The runtime provisions embedded PostgreSQL. If automatic provisioning is unavailable, configure a working external PostgreSQL instance using `JAC_DB_URL` according to `jac guide jac-sv-persistence`.

Official installer (inspect it before executing):

```bash
curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash -s -- --version 0.37.17
jac --version
```

The locally tested platform is Apple Silicon macOS. Use a supported binary for your platform; syntax and workspace behavior are version-sensitive.

## Start the web app and server

From a fresh checkout, enter the repository root. On Apple Silicon macOS with Jac 0.37.17, create the project environment with Homebrew Python **before** installing dependencies:

```bash
brew install python@3.14
"$(brew --prefix python@3.14)/bin/python3.14" -m venv .jac/venv
```

This avoids a locally reproduced bundled-Python `pyexpat` symbol failure that prevents `ensurepip` from installing pip. If `.jac/venv` already exists and `jac install` reports missing pip, stop the app, preserve that environment, and recreate only the venv:

```bash
mv .jac/venv ".jac/venv-backup-$(date +%Y%m%d-%H%M%S)"
"$(brew --prefix python@3.14)/bin/python3.14" -m venv .jac/venv
```

Do not remove `.jac/data`. On other supported platforms, first try the ordinary Jac installation. Then:

```bash
jac install
jac run
```

Open the URL printed by Jac (normally `http://127.0.0.1:8000`). The default app is `web`; one command starts its frontend (8000) and backend API (8001). Web requests use the frontend proxy; CLI and mobile default to API port 8001. If ports differ, use the API URL printed by Jac. Create an account with a unique username and a password of at least 8 characters, then add a task. An email address is not needed. Use the same username/password on the other interfaces.

The server binds to loopback by default. Task data belongs to the server's persistent graph, not browser local storage. Tokens stay in web/mobile memory only: refreshing the page or restarting the mobile app requires signing in again, but must not erase tasks. Click **Refresh** after another device changes data; synchronization is manual, not real-time push.

## CLI

Keep the server running in another terminal. Run these from the repository root:

```bash
jac run cli login YOUR_USERNAME
# Or create an account:
jac run cli register YOUR_USERNAME

jac run cli add "Finish planner README" --course "EECS 449" --due 2026-10-05 --priority 3 --minutes 60
jac run cli list
jac run cli list --today
jac run cli list --all
jac run cli --json list
jac run cli plan --day 2026-10-05 --minutes 120
jac run cli done FULL_TASK_ID
jac run cli reopen FULL_TASK_ID
jac run cli logout
```

Copy the full `ID:` value printed by `list`; IDs are not task titles or row numbers. `--today` includes overdue tasks. Global options belong **before** the command:

```bash
jac run cli --server http://127.0.0.1:8001 --json list
```

Passwords are entered using a hidden prompt and never saved. CLI login stores a token and exact server URL in `.jac/cli-session.json` with owner-only permissions. Logout removes only this local session, not tasks. `.jac/` must never be committed. For scripts, `MAIZEPLAN_TOKEN` may supply a token instead of the local session file. The CLI refuses to reuse a token for a different saved server URL.

## Mobile app

The mobile UI is written in Jac (`mobile/Phone.jac`) using MobUI / React Native. It provides **Tasks**, **Add**, and **Focus** screens connected to the same planning API as the web and CLI. The phone runs the mobile client; the computer must keep serving both the backend and the development bundle.

### Runtime and build options

**Expo Go and Expo SDK 57 are different concepts.** Expo Go is a prebuilt development client installed on a phone. Expo SDK 57 is the framework/library version selected by the current Jac-generated mobile scaffold. SDK 57 can be used with Expo Go, a custom development client, or a standalone app.

| Route | What runs on the phone | Build environment |
|---|---|---|
| Compatible Expo Go | MaizePlan's development bundle inside Expo Go | Jac + Metro on the computer; no local iOS app compilation |
| Custom development build | A dedicated MaizePlan development app with its own native dependencies | Local native tools or EAS Build; requires additional `expo-dev-client` configuration |
| Standalone app | An installed MaizePlan app with its bundled UI | Local Android/iOS tools or a configured cloud builder; signing/distribution depends on platform |
| Browser preview | The mobile UI rendered through React Native Web | Jac browser build; useful for previewing screens and backend workflows |

Local versus cloud describes **where compilation happens**, not a different mobile UI implementation. EAS Build can compile in the cloud without full Xcode installed on your computer. Development builds still load development code through Metro; a standalone release bundles its UI, but still needs a reachable planning backend.

The detailed phone workflow below uses Expo Go. Custom development builds and EAS distribution are alternatives requiring their own configuration; this repository does not include a published cloud build or signed binary. See Expo's [development-build overview](https://docs.expo.dev/develop/development-builds/introduction/), [cloud build setup](https://docs.expo.dev/build/setup/), and [local build overview](https://docs.expo.dev/guides/local-app-overview/).

You may use VS Code for every route. Local iOS compilation/simulators require Apple's Xcode toolchain. The measured mobile coverage is the React Native Web build and UI/backend workflow. See [VALIDATION.md](VALIDATION.md).

### 1. Prepare a compatible phone client

Complete the Jac 0.37.17 and project setup above. Connect your computer and phone to the same trusted Wi-Fi network.

The current Jac scaffold generates **Expo SDK 57** (`"expo": "~57.0.0"` in `.jac/mobile-rn/package.json`). The installed Expo Go must support that SDK:

- **Android phone:** visit [Expo Go downloads](https://expo.dev/go), select SDK 57 and Android physical device, and follow the official installation instructions. Do not assume the Play Store version matches.
- **iPhone:** current Expo documentation says the App Store Expo Go stops at SDK 54. For this SDK 57 project, follow the official [physical iPhone instructions](https://docs.expo.dev/troubleshooting/expo-go-version-mismatch/#physical-iphone-or-ipad): `eas go` can build a compatible Expo Go for distribution through a TestFlight internal team and requires Apple Developer Program membership. This is a separate cloud/account setup, not a local Xcode build. If that setup is unavailable, use a compatible Android phone rather than expecting the App Store client to work.

Recheck the [official compatibility guide](https://docs.expo.dev/troubleshooting/expo-go-version-mismatch/) if the SDK/client versions change. Do not downgrade Expo alone: React Native and the Jac scaffold dependencies must remain compatible.

### 2. Start the shared planning server — terminal A

Find the computer's LAN IPv4 address in its Wi-Fi/network settings, for example `192.168.1.42`. On macOS, `ipconfig getifaddr en0` may show it; if it returns nothing, use the active Wi-Fi interface shown in Settings. Replace the example IP everywhere below with your actual address.

Stop any existing `jac run` in this project with Ctrl+C, then run from the repository root:

```bash
jac run --host 0.0.0.0 --port 8000 --api-port 8001
```

Keep terminal A open. Web uses port **8000**, and planning API requests use port **8001**. On the phone, open `http://192.168.1.42:8000` in its browser to check basic network reachability. This browser check is not the mobile app itself. Create an account on the web, or use an existing MaizePlan account.

Use a trusted network, and change Jac's default administrator credentials before making the development server LAN-accessible. Use HTTPS for a remotely hosted backend; this project does not provision one.

### 3. Start the mobile development bundle — terminal B

Jac 0.37.17's mobile dev command also starts a helper API process. To keep that process separate from the planning server's database/session, run it from an isolated source copy. In a **second terminal, initially at the original repository root**, run:

```bash
# macOS/Linux shell; copies source only, not user data or tokens.
PHONE_WORKSPACE="$(mktemp -d "${TMPDIR:-/tmp}/maizeplan-phone.XXXXXX")"
cp jac.toml "$PHONE_WORKSPACE/"
cp -R core web mobile cli "$PHONE_WORKSPACE/"
cd "$PHONE_WORKSPACE"
jac setup mobile

# Replace this example with your computer's LAN IP.
JAC_RN_DEV_HOST=192.168.1.42 jac run --dev --port 8002 --api-port 8002 mobile
```

`jac setup mobile` downloads the Expo dependencies. The dev command compiles the Jac mobile client and starts Expo/Metro; it does not request `jac build --platform ios`. Keep terminal B open. Metro normally uses **8081**; use the actual address/QR code printed in the terminal. If the Expo terminal is targeting a development build, use its displayed option to switch to Expo Go.

This temporary workspace is only for serving mobile code. The phone must use the **original planning API on 8001**, not the helper API on 8002, even if Jac prints 8002 as its dev API. MaizePlan's explicit **Server URL** field controls its task requests. Source edits in the original directory do not update this copy; recreate the copy when you want to try changed source. On Windows, use a separate source-only copy/checkout and set `JAC_RN_DEV_HOST` using your shell's environment-variable syntax.

### 4. Open MaizePlan on the phone

1. With a compatible Expo Go installed, scan the Metro QR code. On Android, use the Expo Go scanner; on iPhone, use Camera and open the link in the compatible Expo Go app.
2. If iOS asks for local-network access, allow it so the app can reach your computer. Wait for the bundle to load and the MaizePlan login screen to appear.
3. Replace the login screen's **Server URL** with `http://192.168.1.42:8001` (your actual computer IP).
4. Sign in with the **same MaizePlan username/password** used on the web. This is distinct from any Expo account used to obtain the phone client.

Never leave `localhost` as the phone's Server URL: it refers to the phone itself. Metro's `exp://...:8081` address loads the app code; it is not the planning API URL.

Expo's [device-start guide](https://docs.expo.dev/get-started/start-developing/) describes the QR and Wi-Fi workflow.

### 5. Use the mobile screens

- **Tasks:** view course, deadline, estimate and priority; tap **Mark complete** or **Reopen task**. Tap **Refresh from server** after changing tasks on another interface.
- **Add:** enter a title, optional course, `YYYY-MM-DD` deadline, estimate of 5–1440 minutes, and priority 1–3; tap **Add task**.
- **Focus:** enter a planning date and a budget of 5–720 minutes; tap **Make my plan**. The budget includes breaks, and due/overdue work that does not fit is reported.
- **Sign out:** ends the in-memory session. Tasks remain on the backend; reopening/reloading the app requires signing in again.

For a cross-device demo, add a task on the web, refresh Tasks on the phone, complete it on the phone, and refresh the web's Done view. Run `jac run cli list --all` from the **original project directory** to see the same task. Reopen it with `jac run cli reopen FULL_TASK_ID`, then refresh the phone. No automatic live synchronization is implemented.

### Troubleshooting

| Symptom | What to check |
|---|---|
| “Project is incompatible with this version of Expo Go” | Match the scaffold's Expo SDK to the phone client using the compatibility guide above; ordinary App Store Expo Go is not sufficient for SDK 57. |
| QR opens no app / bundle cannot load | Check the compatible client, terminal B, actual Metro address/port, same Wi-Fi, local-network permission, and firewall access. Campus/guest Wi-Fi may block device-to-device traffic. |
| App opens but login/tasks fail | Check terminal A, the explicit Server URL, and port 8001. A working Metro bundle does not establish API reachability. |
| Phone shows different/empty tasks | Use the original server and same MaizePlan account, then Refresh. Do not connect to the mobile helper API on 8002. |
| Ports/database already in use | Stop the previous process you launched, and keep mobile dev in the separate source copy. Do not delete `.jac/data` or take over the original server session. |
| Native-module or generated-code error | Record the exact message and SDK/client versions. Check that the chosen client includes the required native modules; use the selected build route’s diagnostics. |

An Expo tunnel only makes the development bundle reachable; it does not automatically expose the separate planning API. Prefer a trusted network that permits direct LAN access for this workflow. Stop both development terminals with Ctrl+C when finished; preserve the original project's `.jac/data`.

### Optional browser preview

Keep the original `jac run` running. In another terminal at the original repository root:

```bash
jac build --platform web mobile
python3 -m http.server 8010 --bind 127.0.0.1 --directory .jac/client/mobile/dist
```

Open `http://127.0.0.1:8010` and set **Server URL** to `http://127.0.0.1:8001`. This tested route renders the mobile source through React Native Web; it is not evidence of phone execution.

### Optional standalone native builds

EC1 does not explicitly request IPA/APK packaging or App Store distribution. The following commands are optional alternatives, with platform-specific prerequisites:

```bash
jac setup mobile
jac build --platform android mobile
# Requires full Xcode and the iOS toolchain for a local build:
jac build --platform ios mobile
```

See `jac guide jac-mobile-app` for platform prerequisites and the `android_builder` / `ios_builder` settings for EAS. Cloud builds require Expo account/project configuration and appropriate signing credentials. Expo Go development does not invoke the standalone iOS packaging step.

## How the four components fit together

| Component | Source | Responsibility |
|---|---|---|
| Jac server | `core/api.jac`, `core/planning.jac` | Validate and persist tasks under the authenticated user's root; generate focus plans |
| Web | `web/` | Full task editing, search/filter, task summary, planning |
| Native mobile | `mobile/` | Quick capture, check/complete/reopen, focus plan; MobUI native controls |
| CLI | `cli/main.jac` | Terminal capture, listing, completion/reopening, planning and JSON output |
| Shared client transport | `core/client.jac` | Web/mobile login and HTTP requests to the explicitly selected backend |

`web/main.jac` imports each planning endpoint so Jac registers it at `/function/<name>`. The clients POST parameter JSON and read Jac's `data.result` envelope. Web/mobile share transport code; CLI uses Python's standard HTTP library **from Jac**. All planning logic lives on the server—there are no independent browser/phone/CLI task stores to drift apart.

The API declarations use `:protect`: project-visible, but still authenticated. Under this Jac version, only `:pub` skips authentication. Task updates search only the caller's own root rather than trusting a client-supplied task ID.

## Why this project stands out

The key design choice is an achievable plan, not a longer task list. The scheduler accounts for recovery breaks, partially schedules large assignments, and makes overload visible. Its deterministic rules are understandable and testable. Different interfaces suit different moments: organize on the web, check off on a phone, and capture from a terminal. Honest limitations and reproducible verification are part of the design.

## Tests and demonstration

```bash
jac test core/planning.jac
jac build --check_only
jac build web
jac build --platform web mobile
```

With the real backend running, run:

```bash
python3 scripts/smoke_test.py
```

This creates two uniquely named **test accounts** and test tasks on the selected development server. It tests authentication, isolation (including cross-account edits), invalid input rejection, edits, CLI capture/completion, and exact CLI/API planning consistency. It does not remove those accounts or modify real users' tasks. Run only against your development instance.

To verify persistence reproducibly:

```bash
python3 scripts/smoke_test.py --write-restart-state .jac/restart-check.json
# Stop the server with Ctrl+C, then restart it with jac run.
python3 scripts/smoke_test.py --verify-restart-state .jac/restart-check.json
```

The state file contains only a disposable test account token and expected task snapshot, is owner-readable only, and remains under ignored `.jac/`. Use the same `--server` URL for both commands when overriding the default.

The following demonstration covers the shared planning workflow. Use the mobile setup above when demonstrating it on a phone:

1. On the web, register and add one real test task. Edit its estimate and deadline.
2. Sign into the same server on the mobile app; Refresh and confirm the edit appears.
3. Complete it on the phone. Refresh the web; it must appear under Done.
4. Reopen it via CLI. Refresh both UIs and confirm it is open.
5. Generate the same date/budget plan in each interface; results must agree.
6. Stop and restart the original server with `jac run`, sign in again, and verify the task and completion state remain.
7. Sign in as another account; it must not see or modify the first account's task.
8. Disconnect the backend: each interface should report an error, not fake success. Reconnect and retry.
9. Run on an actual iOS/Android device or simulator; check keyboard behavior, scrolling, and backend reachability.

Recorded results include source-only-copy installation, UI/API/CLI integration, and process-restart persistence. [VALIDATION.md](VALIDATION.md) distinguishes measured coverage from additional demonstration scenarios.

## Submission

EC1 is submitted as a GitHub repository link through Canvas. Include the Jac source, `jac.toml`, tests, README, and validation record. Keep `.jac/`, tokens, databases, `node_modules/`, and generated build artifacts out of version control. The student identity is listed at the top of this document.

## Resources and attribution

- [Course syllabus](https://github.com/marsninja/CSE449-F26)
- [Official Jac source and complete workspace](https://github.com/jaseci-labs/jac/tree/main/jac/examples/jaclang_org)
- [Jac documentation](https://jaclang.org/docs/latest)
- [Course-provided AI day-planner guide](https://jaclang.org/docs/v0.37/tutorials/first-app/build-ai-day-planner)
- Bundled Jac 0.37.17 guides: essentials, fullstack patterns, persistence/auth, MobUI, mobile app, client components, and testing.

The task planner, UI, tests, and documentation were developed with AI assistance. Workspace organization and language patterns follow the official examples.
