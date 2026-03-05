# Phase 7: CI/CD & Electron Distribution — Research

**Researched:** 2026-03-05
**Domain:** GitHub Actions, electron-builder, GHCR Docker publishing, Rust PTT daemon bundling
**Confidence:** HIGH

---

## Summary

This phase introduces zero-manual-intervention release automation: pushing a semver tag (e.g., `v1.2.0`) triggers GitHub Actions workflows that build Electron installers for Linux and Windows, attach them to a GitHub Release, and simultaneously build and push a Docker image to GHCR for the server component. The project currently has a working `Dockerfile` for the server, an Electron client in `electron-client/`, and a Rust PTT daemon in `electron-client/ptt-daemon/`, but **no `.github/workflows/` directory exists yet**.

The critical technical constraint is that native Node modules (`uiohook-napi`) and the Rust PTT daemon must be compiled on their target OS runner — cross-compilation is not viable. Linux builds must run on `ubuntu-latest` and Windows builds on `windows-latest`. The Rust daemon is Linux-only (uses `evdev`) so it only needs to be compiled in the Linux job. Windows relies on `uiohook-napi` as its PTT backend, which provides prebuilt Node-API binaries that electron-builder handles automatically.

The current `package.json` in `electron-client/` uses `@electron/packager` which does NOT produce installers (AppImage, deb, NSIS). It must be **replaced with `electron-builder`**, which handles installer generation, GitHub Releases publishing, and native module rebuilding in a single tool.

**Primary recommendation:** Use `electron-builder` with two separate GitHub Actions jobs (Linux runner, Windows runner), triggered on `push: tags: ['v*.*.*']`, with the Rust daemon compiled as a pre-step in the Linux job and bundled via `asarUnpack`. Use official Docker actions for GHCR publishing in a third job.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DIST-01 | GitHub Actions builds Electron app for Linux (.AppImage, .deb) on release tag | electron-builder `linux: { target: ["AppImage", "deb"] }`, ubuntu-latest runner, tag trigger |
| DIST-02 | GitHub Actions builds Electron app for Windows (.exe or .msi) on release tag | electron-builder `win: { target: ["nsis"] }`, windows-latest runner, same tag trigger |
| DIST-03 | Built Electron artifacts are published to GitHub Releases automatically | electron-builder `publish: { provider: "github" }`, `GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}` |
| DIST-04 | GitHub Actions builds and pushes Docker image to GHCR on release tag | docker/build-push-action, docker/login-action with GITHUB_TOKEN, `packages: write` permission |
</phase_requirements>

---

## Standard Stack

### Core
| Library/Tool | Version | Purpose | Why Standard |
|---|---|---|---|
| `electron-builder` | ^25.x | Package Electron into AppImage, deb, NSIS; publish to GitHub Releases | Only tool with built-in GitHub Releases publishing, installer generation, and native module rebuild |
| `actions/checkout` | v4 | Checkout repo in CI | Official GitHub action |
| `actions/setup-node` | v4 | Node.js setup with caching | Official GitHub action |
| `docker/login-action` | v3 | GHCR authentication | Official Docker action |
| `docker/metadata-action` | v5 | Semver tag extraction for Docker image tags | Official Docker action |
| `docker/build-push-action` | v6 | Build and push Docker image | Official Docker action |
| `dtolnay/rust-toolchain` | stable | Install Rust in CI | Canonical Rust toolchain action |

### What Must Change in electron-client/package.json
The current `build` script uses `electron-packager`, which does not produce installable formats. **Replace with electron-builder.**

Current (must remove):
```json
"@electron/packager": "^19.0.3"
```

Required additions:
```json
"electron-builder": "^25.0.0"
```

**Installation:**
```bash
# In electron-client/
npm install --save-dev electron-builder
npm uninstall @electron/packager
```

### Docker Workflow Actions
```yaml
# Standard three-action combo for GHCR publishing
- uses: docker/login-action@v3
- uses: docker/metadata-action@v5
- uses: docker/build-push-action@v6
```

---

## Architecture Patterns

### Recommended Workflow Structure

Two separate workflows or one workflow with parallel jobs:

```
.github/
└── workflows/
    ├── release-electron.yml   # Electron builds (Linux + Windows matrix)
    └── release-docker.yml     # Docker image → GHCR
```

Alternatively, a single `release.yml` with three jobs: `build-linux`, `build-windows`, `build-docker`.

### Recommended Project Structure Changes

```
electron-client/
├── build/
│   ├── icon.png              # Required by electron-builder for Linux/Windows icons
│   └── icon.ico              # Windows-specific icon (optional but recommended)
├── package.json              # Updated with "build" config for electron-builder
└── ptt-daemon/
    └── target/release/       # Rust binary compiled before electron-builder runs
```

### Pattern 1: Tag-Triggered Workflow with OS Matrix

**What:** A single GitHub Actions workflow file with a job matrix running on `ubuntu-latest` and `windows-latest`, triggered only when a `v*.*.*` tag is pushed.

**When to use:** When builds on different platforms share similar steps but need native OS runners.

```yaml
# Source: https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs
name: Release Electron

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  build:
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            platform: linux
          - os: windows-latest
            platform: win
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'
          cache-dependency-path: electron-client/package-lock.json
```

### Pattern 2: Rust Daemon Pre-Build Step (Linux only)

**What:** Before running electron-builder, compile the Rust PTT daemon on the Linux runner and place the binary where electron-builder can bundle it.

**When to use:** The Rust daemon is Linux-only (`evdev` dependency). Windows job skips this step.

```yaml
# Linux job only
- name: Install Rust toolchain
  if: matrix.platform == 'linux'
  uses: dtolnay/rust-toolchain@stable

- name: Build PTT daemon
  if: matrix.platform == 'linux'
  working-directory: electron-client/ptt-daemon
  run: cargo build --release

# electron-builder will pick this up via asarUnpack configuration
```

The binary lands at `electron-client/ptt-daemon/target/release/ptt-daemon`. The `asarUnpack` config ensures it is NOT packed into the asar archive (required because `child_process.spawn` cannot execute files inside asar).

### Pattern 3: electron-builder package.json Configuration

**What:** The `"build"` section in `electron-client/package.json` tells electron-builder which targets to produce and where to publish.

```json
{
  "name": "cromulent-voice-chat",
  "version": "1.0.0",
  "description": "Cromulent Voice chat desktop client",
  "main": "main.js",
  "build": {
    "appId": "dev.cromulent.voice",
    "productName": "Cromulent",
    "directories": {
      "buildResources": "build"
    },
    "files": [
      "**/*",
      "!ptt-daemon/target/**",
      "ptt-daemon/target/release/ptt-daemon"
    ],
    "asarUnpack": [
      "ptt-daemon/target/release/ptt-daemon"
    ],
    "linux": {
      "target": ["AppImage", "deb"],
      "category": "AudioVideo"
    },
    "win": {
      "target": ["nsis"]
    },
    "nsis": {
      "oneClick": true,
      "perMachine": false
    },
    "publish": {
      "provider": "github"
    }
  },
  "scripts": {
    "start": "electron .",
    "dist": "electron-builder"
  }
}
```

### Pattern 4: GHCR Docker Publish Workflow

**What:** Build the existing `Dockerfile` (Phoenix server) and push to `ghcr.io/OWNER/cromulent` with semver tags.

```yaml
# Source: https://docs.github.com/actions/guides/publishing-docker-images
name: Release Docker

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  docker:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v4

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=raw,value=latest

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

### Pattern 5: Publishing Electron Artifacts to GitHub Releases

**What:** electron-builder with `--publish always` and `GH_TOKEN` automatically creates the GitHub Release (if it doesn't exist) and attaches artifacts. The tag must already exist (it was pushed to trigger the workflow).

```yaml
- name: Build and publish Electron
  working-directory: electron-client
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    npm ci
    npx electron-builder --publish always
```

The `--publish always` flag tells electron-builder to publish regardless of whether the build is from a tagged commit (the tag filter in the `on:` trigger handles that gating). The `GH_TOKEN` is automatically available in GitHub Actions — no additional secret setup needed.

### Anti-Patterns to Avoid

- **Using `@electron/packager` for distribution:** Produces a directory of raw files, not installable packages. Does not produce AppImage, deb, or NSIS.
- **Cross-OS building in a single runner:** Native modules (`uiohook-napi`, Rust daemon) must be compiled on the target OS. A Linux runner cannot produce correct Windows native binaries.
- **Packing the Rust daemon inside asar:** `child_process.spawn` cannot execute binaries from inside an asar archive. Always use `asarUnpack` for executables.
- **Hardcoding `ptt-daemon/target/debug/` in main.js for production:** The production build should reference `target/release/`. The current `main.js` hardcodes `target/debug` — this should be updated before bundling.
- **Running the Rust build step on Windows:** `evdev` is a Linux-only crate. The Rust daemon does not build on Windows and is not needed there (uiohook-napi handles Windows PTT).
- **Setting `releaseType: "draft"` unintentionally:** electron-builder defaults to creating draft releases. For automatic publishing, set `releaseType: "release"` or handle draft promotion separately.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Installer packaging | Custom zip/tar scripts | `electron-builder` | NSIS, AppImage, deb involve complex spec files, desktop entries, icon embedding, signing hooks |
| GitHub Release creation | `gh` CLI or curl to REST API | `electron-builder --publish always` | electron-builder handles artifact upload, release creation, and idempotency atomically |
| Docker image tagging | Manual tag scripts | `docker/metadata-action@v5` | Handles semver, `latest`, sha, branch tagging with correct labels automatically |
| GHCR auth | PAT secrets | `GITHUB_TOKEN` + `packages: write` permission | No secret management needed; scoped to repo automatically |
| Native module rebuild | Manual `node-gyp rebuild` | `electron-builder install-app-deps` (auto-run) | electron-builder automatically detects and rebuilds native modules during packaging |

---

## Common Pitfalls

### Pitfall 1: Rust Daemon Path Hardcoded to `target/debug`
**What goes wrong:** `main.js` has `path.join(__dirname, 'ptt-daemon', 'target', 'debug', 'ptt-daemon')`. When the CI build uses `cargo build --release`, the binary lands in `target/release/`. The bundled app fails to find the daemon.
**Why it happens:** Debug path was used during local development.
**How to avoid:** Update `main.js` to reference `target/release/ptt-daemon` (or use an env/isDev check). This must be done before writing the CI workflow.
**Warning signs:** PTT backend silently falls through to uiohook-napi on Linux in the distributed build.

### Pitfall 2: `uiohook-napi` Rebuild Fails on Windows Runner
**What goes wrong:** `uiohook-napi` requires native compilation on Windows. The Windows runner needs Visual Studio Build Tools for C++ compilation via `node-gyp`. The GitHub `windows-latest` runner includes VS Build Tools, but `npm ci` + electron-builder's auto-rebuild can fail if the environment differs from expectations.
**Why it happens:** Native modules need to be compiled against Electron's Node ABI, not system Node.
**How to avoid:** electron-builder's `install-app-deps` (called automatically during `electron-builder`) handles this. Ensure Node version in `setup-node` matches the Node ABI target of the Electron version in use.
**Warning signs:** Build fails with `gyp ERR! build error` on Windows job.

### Pitfall 3: electron-builder Targets Must Match Runner OS
**What goes wrong:** Specifying `linux` targets in the `build` section causes errors when running on a Windows runner, and vice versa.
**How to avoid:** Use `--linux` and `--win` CLI flags explicitly per-job, OR rely on electron-builder's auto-detection (it builds for the current OS by default). With the matrix approach, let electron-builder detect the OS automatically — no `--linux` or `--win` flag needed.

### Pitfall 4: GHCR Image Not Publicly Visible
**What goes wrong:** After pushing to GHCR, the image shows in the repository's Packages tab but is not publicly accessible for `docker pull` without authentication.
**Why it happens:** New GHCR packages default to private visibility.
**How to avoid:** After the first successful push, go to the package settings on GitHub and set visibility to Public. This is a one-time manual step. Alternatively, it can be scripted via the GitHub API if desired.

### Pitfall 5: electron-builder Creates Draft Release Instead of Published Release
**What goes wrong:** Artifacts are uploaded but the GitHub Release is in "Draft" state, not publicly visible.
**Why it happens:** `electron-builder` defaults `releaseType` to `"draft"`.
**How to avoid:** Add `"releaseType": "release"` to the `publish` config in `package.json`, or pass `--publish always` and set the environment variable `EP_DRAFT=false`.

### Pitfall 6: `files` Glob Excludes Rust Binary
**What goes wrong:** electron-builder's default `files` glob excludes large build directories. The Rust `target/` directory is typically excluded entirely by default globs.
**How to avoid:** Explicitly include the release binary in the `files` array with a negative+positive glob pattern:
```json
"files": [
  "**/*",
  "!ptt-daemon/target/**",
  "ptt-daemon/target/release/ptt-daemon"
]
```

### Pitfall 7: `GITHUB_TOKEN` Permissions on `electron-builder --publish`
**What goes wrong:** electron-builder upload fails with a 403 error when trying to create or upload to GitHub Releases.
**Why it happens:** The workflow job needs `contents: write` permission to create releases and upload assets.
**How to avoid:** Add explicit permissions to the Electron build job:
```yaml
permissions:
  contents: write
```

---

## Code Examples

### Complete Electron Release Workflow (recommended structure)

```yaml
# Source: electron-builder docs + GitHub Actions docs
# .github/workflows/release-electron.yml
name: Release Electron

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  build:
    strategy:
      fail-fast: false
      matrix:
        include:
          - os: ubuntu-latest
            platform: linux
          - os: windows-latest
            platform: win
    runs-on: ${{ matrix.os }}
    permissions:
      contents: write

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'
          cache-dependency-path: electron-client/package-lock.json

      # Linux only: compile Rust PTT daemon
      - name: Install Rust toolchain
        if: matrix.platform == 'linux'
        uses: dtolnay/rust-toolchain@stable

      - name: Build PTT daemon (Linux)
        if: matrix.platform == 'linux'
        working-directory: electron-client/ptt-daemon
        run: cargo build --release

      - name: Install dependencies and build
        working-directory: electron-client
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          npm ci
          npx electron-builder --publish always
```

### Complete Docker/GHCR Workflow

```yaml
# Source: https://docs.github.com/actions/guides/publishing-docker-images
# .github/workflows/release-docker.yml
name: Release Docker

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  docker:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=raw,value=latest

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

### electron-builder Configuration in package.json

```json
{
  "name": "cromulent-voice-chat",
  "version": "1.0.0",
  "description": "Cromulent Voice chat desktop client",
  "main": "main.js",
  "build": {
    "appId": "dev.cromulent.voice",
    "productName": "Cromulent",
    "directories": {
      "buildResources": "build"
    },
    "files": [
      "**/*",
      "!ptt-daemon/target/**",
      "ptt-daemon/target/release/ptt-daemon"
    ],
    "asarUnpack": [
      "ptt-daemon/target/release/ptt-daemon"
    ],
    "linux": {
      "target": ["AppImage", "deb"],
      "category": "AudioVideo"
    },
    "win": {
      "target": ["nsis"]
    },
    "nsis": {
      "oneClick": true,
      "perMachine": false
    },
    "publish": {
      "provider": "github",
      "releaseType": "release"
    }
  },
  "scripts": {
    "start": "electron .",
    "dist": "electron-builder",
    "pack": "electron-builder --dir"
  },
  "devDependencies": {
    "electron": "^40.4.0",
    "electron-builder": "^25.0.0"
  },
  "dependencies": {
    "electron-localshortcut": "^3.2.1",
    "electron-store": "^11.0.2",
    "uiohook-napi": "^1.5.4"
  }
}
```

### Fixing the PTT Daemon Path in main.js

Current hardcoded path (must change):
```javascript
// Current (development only)
const daemonPath = path.join(__dirname, 'ptt-daemon', 'target', 'debug', 'ptt-daemon');
```

Updated for production builds:
```javascript
// Production: binary is in release build, unpacked from asar
const daemonPath = path.join(
  app.isPackaged
    ? process.resourcesPath
    : __dirname,
  app.isPackaged
    ? 'app.asar.unpacked/ptt-daemon/target/release/ptt-daemon'
    : 'ptt-daemon/target/release/ptt-daemon'
);
```

Note: `app.isPackaged` is `true` when running from a distributed build. When packaged, electron-builder places `asarUnpack` files in `resources/app.asar.unpacked/`.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| `electron-packager` | `electron-builder` | ~2018; accelerated post-2020 | electron-builder is the de-facto standard; packager is maintenance mode |
| Docker Hub for publishing | GHCR (GitHub Container Registry) | 2020-2021 | GHCR uses GITHUB_TOKEN; no external account needed |
| Manual `GH_TOKEN` secret | Automatic `GITHUB_TOKEN` with `packages: write` | 2021 | No manual secret creation for GHCR |
| Draft releases requiring manual publish | `releaseType: "release"` in electron-builder config | Available throughout | Must explicitly opt in to non-draft |
| `actions-rs/toolchain` | `dtolnay/rust-toolchain` | ~2023 | `actions-rs` is archived/unmaintained |

**Deprecated/outdated:**
- `@electron/packager` (formerly `electron-packager`): Does not produce installable packages; use electron-builder
- `actions-rs/toolchain@v1`: Archived; use `dtolnay/rust-toolchain@stable`
- Docker Hub PAT secrets for GHCR auth: Use `GITHUB_TOKEN` with `packages: write` permission

---

## Open Questions

1. **Windows Code Signing**
   - What we know: electron-builder supports Windows code signing via `CSC_LINK`/`CSC_KEY_PASSWORD` environment variables, or Azure Trusted Signing for cloud-based signing.
   - What's unclear: The project does not appear to have a code signing certificate. Without signing, Windows SmartScreen will show an "Unknown Publisher" warning on first run.
   - Recommendation: Skip signing for v1.1 (open-source self-hosted tool; SmartScreen warning is acceptable). Document the warning in the release notes. Code signing can be added later.

2. **Electron Version 40 Compatibility with electron-builder**
   - What we know: The project uses `electron@^40.4.0`, which is a very recent version. electron-builder v25+ supports recent Electron versions.
   - What's unclear: Whether any specific electron-builder version pinning is needed for Electron 40. electron-builder's `install-app-deps` must use the correct Electron version ABI for native module rebuilds.
   - Recommendation: Use `electron-builder@latest` (v25+) and verify the `electronVersion` is auto-detected from `devDependencies`. If rebuild fails, explicitly set `electronVersion` in the build config.

3. **Application Icon**
   - What we know: electron-builder requires icons in `build/icon.png` (Linux, min 512x512) and `build/icon.ico` (Windows) for branded installers.
   - What's unclear: The project has no icon assets currently.
   - Recommendation: Create a minimal placeholder icon for v1.1. Without one, electron-builder uses the default Electron icon, which is functional but unbranded.

4. **`electron-store` Compatibility on Windows**
   - What we know: `electron-store@^11.0.2` is in use. Version 11 is ESM-only and may require `import()` rather than `require()`.
   - What's unclear: Whether the current `main.js` (using `const Store = require('electron-store')` with the `Store.default || Store` workaround) works correctly when packaged on Windows.
   - Recommendation: Test locally on Windows before relying on CI, or ensure the workaround is valid for the installed version.

---

## Sources

### Primary (HIGH confidence)
- [electron-builder official docs](https://www.electron.build/) — configuration, targets, publish, multi-platform build
- [electron-builder publish docs](https://www.electron.build/publish.html) — GitHub Releases publishing, GH_TOKEN, releaseType
- [electron-builder multi-platform docs](https://www.electron.build/multi-platform-build.html) — native dependency constraints, runner requirements
- [GitHub Docs: Publishing Docker images](https://docs.github.com/actions/guides/publishing-docker-images) — GHCR workflow, GITHUB_TOKEN permissions
- [docker/metadata-action](https://github.com/docker/metadata-action) — semver tag extraction
- [docker/build-push-action](https://github.com/marketplace/actions/build-and-push-docker-images) — canonical build-push action

### Secondary (MEDIUM confidence)
- [Multi-OS Electron Build & Release with GitHub Actions (DEV Community, Oct 2025)](https://dev.to/supersuman/multi-os-electron-build-release-with-github-actions-f3n) — complete workflow example verified against official docs
- [samuelmeuli/action-electron-builder](https://github.com/samuelmeuli/action-electron-builder) — release detection pattern (`startsWith(github.ref, 'refs/tags/v')`)
- [Bundling precompiled binary in Electron (Medium)](https://ganeshrvel.medium.com/bundle-a-precompiled-binary-or-native-file-into-an-electron-app-beacc44322a9) — asarUnpack pattern for executables

### Tertiary (LOW confidence — verify before implementing)
- `dtolnay/rust-toolchain@stable` as replacement for archived `actions-rs/toolchain` — seen in multiple 2024-2025 examples but not from a single authoritative source
- `app.isPackaged` path resolution for asar.unpacked — well-established Electron pattern but specific path must be validated against actual build output

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — electron-builder is the clear standard; Docker actions are official
- Architecture: HIGH — OS matrix pattern is well-documented and verified across multiple sources
- Pitfalls: MEDIUM/HIGH — most are verified from official docs; Windows signing skip is a judgment call
- Rust daemon path fix: MEDIUM — `app.isPackaged` + `process.resourcesPath` is correct Electron API, but specific asar.unpacked path must be tested

**Research date:** 2026-03-05
**Valid until:** 2026-06-05 (electron-builder is relatively stable; Docker actions versioning changes occasionally)
