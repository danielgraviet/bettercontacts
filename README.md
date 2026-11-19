# BetterContacts

Your address book, with a memory. Native iOS (SwiftUI), built for keeping relationships warm:

- **Natural language search** — "who did I meet this week?" just works
- **Filtering & sorting** — close circle, tags, locations, phone presence
- **Smart reminders** — know when a friendship is going quiet
- **Birthdays** — never miss one (leap-year Feb 29 handled)
- **Location tagging** — "everyone I met in Berlin"
- **Touchpoints** — log calls/coffees/texts; staleness scored per contact

Everything runs on-device. No accounts, no cloud, no tracking.

---

## The 30-second version

```
git clone <your-repo> && cd bettercontacts
brew install xcodegen fastlane swiftlint   # one time
make project                               # regenerates the .xcodeproj
open BetterContacts.xcodeproj              # run/test from Xcode, or:
make test                                  # full suite on the simulator
```

Merging to `main` ships a TestFlight build. Tagging `v1.0.0` submits to the App Store. That's the whole release process.

---

## How the repo is laid out

```
project.yml                  # THE project definition. XcodeGen turns this into .xcodeproj
Domain/                      # Pure Swift: all business logic. Zero UI, zero Apple-framework deps.
DomainTests/                 # Google-style unit tests for the Domain (the star of the show)
DomainTestSupport/           # Shared fixtures: deterministic clock, makeContact(), FakeEmbedder
BetterContacts/              # The app: SwiftUI views + adapters (Contacts, SwiftData, NL, UN)
BetterContactsTests/          # ViewModel tests (with a fake repository)
BetterContactsUITests/       # One smoke test — the broad-scoped 20% of the 80/20 rule
fastlane/                    # test / beta / release lanes + App Store metadata
.github/workflows/            # ci.yml (PRs) and deploy.yml (main → TestFlight, tags → App Store)
```

The `.xcodeproj` is **generated, never committed** (see `.gitignore`). After cloning or
editing `project.yml`, run `make project` (or `xcodegen generate`).

**Why XcodeGen?** The project file is deterministic output, so it can't cause merge
conflicts, CI regenerates it identically on every run, and the real source of truth
(`project.yml`) is human-reviewable.

---

## Architecture

```
┌─────────────────────────────────────────────┐
│  BetterContacts (app)                       │
│  SwiftUI views ─ ContactListViewModel       │
│      │ uses                                  │
│  Adapters: CNContactStore · SwiftData store │
│            NLEmbedding · UNNotifications    │
└──────────────┬──────────────────────────────┘
               │ protocols (ContactSourceProviding,
               │            ContactRepositoryStoring, EmbeddingProviding)
┌──────────────▼──────────────────────────────┐
│  Domain (pure Swift framework)              │
│  Contact · ContactFilterEngine · SortEngine  │
│  BirthdayService · TouchpointEngine          │
│  SmartReminderEngine · QueryParser           │
│  SearchEngine (semantic, on-device)         │
└─────────────────────────────────────────────┘
```

The Domain has **no dependencies on UI or system frameworks** — which is exactly
what makes the 60+ unit tests fast, deterministic, and immune to brittleness.
Every dependency that touches the real world (time, embeddings, storage, address
book) is injected. See [TESTING.md](TESTING.md) for the philosophy.

---

## The release pipeline (the part you never have to think about)

| Event | What happens | Human effort |
|---|---|---|
| Pull request opened | SwiftLint (`--strict`) + full test suite on a macOS runner | Merge when green |
| Merge to `main` | Tests → build → sign → **TestFlight upload** | None |
| Tag pushed (`v1.2.0`) | Tests → build → sign → **App Store submission**, version = tag | None |

Build numbers are read from TestFlight and incremented automatically. The
marketing version comes from the git tag. Nobody ever opens Xcode's organizer.

### Releasing a version

```bash
git tag v1.2.0
git push origin v1.2.0
```

When Apple approves, it auto-releases. To promote the latest TestFlight build
manually instead, use App Store Connect or TestFlight's "release" button.

---

## One-time setup

Do these once per machine and once per Apple account.

### 1. Local tooling

```bash
# Xcode 16+ from the Mac App Store, then:
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch        # downloads the iOS platform + simulators

# Xcode 26 moved sourcekitdInProc inside the toolchain; the current SwiftLint
# bottle still expects the old layout, so bridge it once:
sudo mkdir -p /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-6.2/macosx
sudo ln -sfn /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/sourcekitdInProc.framework /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-6.2/macosx/sourcekitdInProc.framework
# (Delete the symlink once a SwiftLint release catches up with Xcode 26.)

brew install xcodegen swiftlint ruby

# Apple's system Ruby (2.6) is deprecated; use Homebrew's. Add to ~/.zshrc:
echo 'export PATH="/opt/homebrew/opt/ruby/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

bundle install                         # fastlane via Bundler, in the repo root
```

The CI workflow does the sourcekitdInProc bridging itself, so that step is
only needed on your own machines.

### 2. App Store Connect API key

App Store Connect → Users and Access → Integrations → **App Store Connect API**
→ create a key with **App Manager** access. Download the `.p8` file (never commit it).

Then create these GitHub repo secrets (Settings → Secrets and variables → Actions):

| Secret | Value |
|---|---|
| `ASC_KEY_ID` | The key ID shown next to your API key |
| `ASC_ISSUER_ID` | The issuer ID at the top of the Integrations page |
| `ASC_KEY_CONTENT` | Base64 of the `.p8` file: `base64 -i AuthKey_XXXXXXXXXX.p8 \| pbcopy` |
| `MATCH_PASSWORD` | A strong passphrase you invent now (see step 3) |
| `MATCH_GIT_URL` | `https://github.com/<you>/bettercontacts-certificates.git` (private) |
| `MATCH_GIT_BASIC_AUTHORIZATION` | Base64 of `<username>:<personal-access-token>` — a PAT with repo access, so CI can clone the cert repo |

### 3. Code signing (fastlane match)

```bash
# Create the empty PRIVATE repo from step 2 first, then:
bundle exec fastlane match appstore
```

This creates/imports your signing certificate + App Store provisioning profile
into that private repo, encrypted with `MATCH_PASSWORD`. CI later runs
`match(type: "appstore", readonly: true)` — it only reads, never modifies.

### 4. Branch protection (recommended)

On GitHub: Settings → Branches → protect `main` → require the **Lint & Test**
check to pass, require PR reviews as you see fit. This makes the pipeline the
enforcer: nothing reaches TestFlight that isn't green and reviewed.

### 5. First screenshots (one-time, for App Store review)

`deliver` skips screenshot management (`skip_screenshots: true`). For your first
App Store submission, upload screenshots once via App Store Connect (or
fastlane snapshot later). The pipeline handles everything else on every release.

---

## Day-to-day workflow

```bash
git checkout -b feature/birthday-widget
# ...code... (regenerate the project if you edited project.yml: make project)
make lint && make test      # same commands CI runs
git commit && git push
# open PR → CI runs → merge → TestFlight build appears minutes later
```

### Verify a TestFlight build locally before pushing a tag

```bash
make beta      # same lane CI runs: build + upload to TestFlight
```

---

## Where things live when something breaks

- **Tests failed on CI** — download the `test-results` artifact from the failed
  run; it contains the full `.xcresult`.
- **Signing errors on CI** — usually `MATCH_GIT_BASIC_AUTHORIZATION` expired or
  the cert repo permissions; re-run `fastlane match appstore` locally to refresh.
- **"iOS xx is not installed"** on a new machine — that's
  `sudo xcodebuild -runFirstLaunch` not having been run (step 1).
- **Bundle ID** — this repo uses `com.danielgraviet.bettercontacts` (see
  `project.yml` and `fastlane/Appfile`). Change it in both places before your
  first App Store Connect app record.

## Roadmap ideas (from notes.txt)

- Richer notification scheduling (recurring nudges, quiet hours)
- iPad + Mac Catalyst layouts
- Custom cadences per contact (weekly, monthly, quarterly)
- Import/export of tags and touchpoints
