# Stack Research

**Domain:** Cromulent v1.1 — Polish & Distribution (avatars, Electron cross-platform builds, Unraid CA template)
**Researched:** 2026-03-04
**Confidence:** HIGH for Phoenix LiveView uploads and electron-builder; MEDIUM for Unraid CA XML schema details

---

## Context: What Is NOT Being Researched

The following are validated v1.0 choices that do not change for v1.1:

- Elixir 1.18.2 / Phoenix 1.7 / Phoenix LiveView 1.0 / PostgreSQL
- Electron 40.x with electron-store, uiohook-napi, electron-localshortcut
- Docker deployment with coturn
- MDEx for markdown, Finch for HTTP, Bandit for web server

Research below covers ONLY the delta for the three new capability areas.

---

## Area 1: Phoenix File Uploads for User Avatars

### Decision: Use Phoenix LiveView's Built-In `allow_upload/3` — No External Library

**Rationale:** Phoenix LiveView 1.0 ships with a complete, production-ready upload system. Libraries like Arc and Waffle exist for S3/cloud storage workflows. Cromulent is self-hosted with local disk storage, so cloud abstractions add zero value. The built-in live uploads system handles chunked upload, client-side validation, and server-side consume in ~30 lines of LiveView code.

**Do not add:** `arc`, `waffle`, `ex_aws` — these are S3/cloud wrappers that introduce AWS SDK overhead for a feature that only needs `File.cp!/2` to disk.

### Core API (Phoenix LiveView 1.0, already in mix.exs as `{:phoenix_live_view, "~> 1.0.0"}`)

| API | Purpose |
|-----|---------|
| `allow_upload/3` in `mount/3` | Declare upload field with accept types, size limit, max entries |
| `<.live_file_input field={@uploads.avatar} />` | LiveView component renders the `<input type="file">` |
| `consume_uploaded_entries/3` in `handle_event` | Read temp file path, copy to permanent location |
| `Phoenix.Component.upload_errors/2` | Extract validation errors for display |

**Key `allow_upload/3` options for avatars:**
```elixir
allow_upload(:avatar,
  accept: ~w(.jpg .jpeg .png .webp .gif),
  max_entries: 1,
  max_file_size: 5_000_000   # 5 MB in bytes
)
```

**Storage pattern:**
```elixir
# In handle_event("save_avatar", ...)
consume_uploaded_entries(socket, :avatar, fn %{path: tmp_path}, entry ->
  filename = "#{user.id}-#{System.unique_integer([:positive])}#{Path.extname(entry.client_name)}"
  dest = Path.join(Application.app_dir(:cromulent, "priv/static/uploads/avatars"), filename)
  File.cp!(tmp_path, dest)
  {:ok, ~p"/uploads/avatars/#{filename}"}
end)
```

**Required: add uploads directory to static paths** in `lib/cromulent_web.ex`:
```elixir
def static_paths, do: ~w(assets fonts images favicon.ico robots.txt uploads)
```

**Source:** [Phoenix LiveView uploads guide](https://hexdocs.pm/phoenix_live_view/uploads.html) — HIGH confidence, official docs for installed version.

### Optional: Image Resizing Library

**Decision: Add `image` hex package only if avatar resizing is needed. Skip for MVP.**

For v1.1, the acceptable avatar sizes are small (5 MB cap), and the use case is a small-group chat. Storing the original upload is acceptable. If thumbnail generation becomes a phase requirement, use the `image` library (elixir-image/image on Hex.pm), which wraps libvips via `vix` for fast, memory-efficient resize — approximately 2-3x faster than Mogrify and 5x less memory.

| Library | Version | Why |
|---------|---------|-----|
| `image` | ~> 0.63 | High-level libvips wrapper, Elixir-idiomatic, prebuilt binaries for Linux (no compile step in Docker) |
| `vix` | ~> 0.35 | Low-level libvips NIF (image depends on it automatically) |

**Do not use `mogrify`** — it shells out to ImageMagick, which must be installed separately in Docker images, complicating the container build. `image`/`vix` include prebuilt libvips binaries via `rustler_precompiled`-style mechanism.

**Source:** [elixir-image/image GitHub](https://github.com/elixir-image/image), [vix Hex.pm](https://hex.pm/packages/vix) — MEDIUM confidence (library docs, no Context7 verification).

---

## Area 2: Electron Cross-Platform Builds via GitHub Actions

### Critical Finding: Migrate from `@electron/packager` to `electron-builder`

The project currently uses `@electron/packager` ^19.0.3 in `electron-client/package.json`. This must change for v1.1.

**Why migrate:**

| Capability | `@electron/packager` | `electron-builder` |
|------------|---------------------|-------------------|
| Windows NSIS installer | No — produces bare .exe dir | Yes — full NSIS installer |
| AppImage (Linux) | No — produces dir, not AppImage | Yes — native AppImage target |
| Auto-update support | No | Yes (via electron-updater) |
| GitHub Releases publish | Manual | Built-in `--publish` flag |
| GitHub Actions integration | Manual workflow | Official action + native support |
| Code signing integration | Manual | Built-in via env vars |
| Native dep rebuild | Manual `@electron/rebuild` step | Built-in `install-app-deps` |

`@electron/packager` is a lower-level tool for creating bare OS bundles. It works for Linux-only simple deployments (which is how v1.0 used it), but does not produce installer formats expected by Windows users and doesn't integrate cleanly with CI distribution pipelines.

**electron-builder version:** 26.x (26.8.1 as of 2025-03 per npm registry) — this is what the GitHub Actions workflow should target.

**Source:** [electron-builder GitHub](https://github.com/electron-userland/electron-builder), [electron-builder docs](https://www.electron.build/) — HIGH confidence.

### electron-builder Configuration

Add to `electron-client/package.json`:

```json
{
  "scripts": {
    "start": "electron .",
    "dist:linux": "electron-builder --linux AppImage",
    "dist:win": "electron-builder --win nsis --x64",
    "postinstall": "electron-builder install-app-deps"
  },
  "devDependencies": {
    "electron": "^40.4.0",
    "electron-builder": "^26.0.0"
  },
  "build": {
    "appId": "com.cromulent.voicechat",
    "productName": "Cromulent",
    "directories": {
      "output": "dist"
    },
    "files": [
      "**/*",
      "!node_modules/.cache",
      "!dist"
    ],
    "linux": {
      "target": ["AppImage"],
      "category": "Network"
    },
    "win": {
      "target": [{"target": "nsis", "arch": ["x64"]}]
    },
    "nsis": {
      "oneClick": true,
      "perMachine": false,
      "allowToChangeInstallationDirectory": false
    }
  }
}
```

**Remove from devDependencies:** `"@electron/packager": "^19.0.3"` — no longer needed.

### GitHub Actions Workflow Structure

**Key insight:** electron-builder cannot cross-compile. Windows `.exe` installers must be built on a `windows-latest` runner. AppImage must be built on `ubuntu-latest`. Use a matrix strategy.

**Recommended workflow: `.github/workflows/release.yml`**

```yaml
name: Build and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            artifact: linux
            build_cmd: npm run dist:linux
          - os: windows-latest
            artifact: windows
            build_cmd: npm run dist:win

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: electron-client/package-lock.json

      - name: Install dependencies
        working-directory: electron-client
        run: npm ci

      - name: Build Electron app
        working-directory: electron-client
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          # Code signing vars (optional — leave unset to skip signing)
          # CSC_LINK: ${{ secrets.WIN_CSC_LINK }}
          # CSC_KEY_PASSWORD: ${{ secrets.WIN_CSC_KEY_PASSWORD }}
        run: ${{ matrix.build_cmd }}

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.artifact }}-build
          path: electron-client/dist/
```

**Trigger strategy:** Tag-based (`v*`) is recommended over branch-based. This lets you control release timing explicitly: `git tag v1.1.0 && git push --tags`.

**Source:** [electron-builder docs - GitHub Actions](https://www.electron.build/), [Electron Builder Action on GitHub Marketplace](https://github.com/marketplace/actions/electron-builder-action) — HIGH confidence.

### Native Dependency Handling: `uiohook-napi` on Windows

**This is the highest-risk area for the Windows build.** `uiohook-napi` is a native Node module (N-API binding). It ships prebuilt binaries for Windows x64, Linux x64, macOS, so `npm ci` should pull the correct prebuilt binary without requiring MSVC or node-gyp compilation on the `windows-latest` runner.

**Verification required during phase implementation:** Confirm uiohook-napi 1.5.4 ships a win32-x64 prebuilt. If it does not, add an `@electron/rebuild` step after `npm ci` to recompile against the Electron headers. The `postinstall: "electron-builder install-app-deps"` script in the build config handles this automatically when electron-builder is used.

**electron-localshortcut** is a pure JS library — no native compilation needed.

**Source:** [uiohook-napi npm](https://www.npmjs.com/package/uiohook-napi), [Electron native modules docs](https://www.electronjs.org/docs/latest/tutorial/using-native-node-modules) — MEDIUM confidence (uiohook-napi prebuilt availability unverified, must test in CI).

### Windows Code Signing: Skip for v1.1

**Decision: Build unsigned Windows installers for v1.1.**

Since June 2023, Microsoft requires EV code signing certificates for SmartScreen-bypass behavior. EV certs require hardware tokens or cloud HSM services (DigiCert KeyLocker, Azure Trusted Signing) and cost $300-500/year. For a self-hosted application targeting technically-minded users, the friction of a SmartScreen warning ("Windows protected your PC") is acceptable. Users can click "More info" → "Run anyway".

**Implementation:** Leave `CSC_LINK` and `CSC_KEY_PASSWORD` unset in the GitHub Actions workflow. electron-builder skips signing silently when these are absent.

**Future path (if signing is needed):** Azure Trusted Signing is the lowest-friction cloud HSM option as of 2024-2025. It integrates with electron-builder via `@electron/windows-sign`. Do not pursue for v1.1.

**Source:** [Electron code signing docs](https://www.electronjs.org/docs/latest/tutorial/code-signing), [electron-builder Windows code signing](https://www.electron.build/code-signing-win.html) — HIGH confidence.

---

## Area 3: Unraid Community Applications Docker Template

### What It Is

An XML file hosted in a public GitHub repository. The Unraid Community Applications plugin indexes template repos and presents them in the Unraid App Store UI. Users click "Install" and Unraid pre-fills Docker configuration from the template.

**No new Elixir or Node.js dependencies required.** This is pure infrastructure/documentation tooling — just an XML file and a GitHub repo.

### Template XML Schema (Unraid CA format)

**Required fields for the Cromulent template:**

```xml
<?xml version="1.0" encoding="utf-8"?>
<Container version="2">
  <!-- Metadata -->
  <Name>Cromulent</Name>
  <Repository>ghcr.io/username/cromulent:latest</Repository>
  <Registry>https://github.com/username/cromulent</Registry>
  <Network>bridge</Network>
  <Shell>sh</Shell>
  <Privileged>false</Privileged>
  <Support>https://github.com/username/cromulent/issues</Support>
  <Project>https://github.com/username/cromulent</Project>
  <Overview>Self-hosted voice and text chat application. Elixir/Phoenix backend with WebRTC voice.</Overview>
  <Category>Network:Messenger</Category>
  <WebUI>http://[IP]:[PORT:4000]/</WebUI>
  <TemplateURL>https://raw.githubusercontent.com/username/cromulent/main/unraid/cromulent.xml</TemplateURL>
  <Icon>https://raw.githubusercontent.com/username/cromulent/main/unraid/icon.png</Icon>
  <ExtraParams></ExtraParams>
  <DateInstalled></DateInstalled>

  <!-- HTTP port -->
  <Config Name="Web UI Port" Target="4000" Default="4000" Mode="tcp"
          Description="Phoenix web server port. Access Cromulent on this port."
          Type="Port" Display="always" Required="true" Mask="false">4000</Config>

  <!-- Environment variables -->
  <Config Name="Database URL" Target="DATABASE_URL" Default="ecto://postgres:password@postgres:5432/cromulent"
          Description="PostgreSQL connection string. Use the postgres service name as host."
          Type="Variable" Display="always" Required="true" Mask="false"></Config>

  <Config Name="Secret Key Base" Target="SECRET_KEY_BASE" Default=""
          Description="Phoenix secret key. Generate with: mix phx.gen.secret"
          Type="Variable" Display="always" Required="true" Mask="true"></Config>

  <Config Name="TURN Secret" Target="TURN_SECRET" Default=""
          Description="HMAC secret for TURN credential generation. Generate with: openssl rand -hex 32"
          Type="Variable" Display="always" Required="true" Mask="true"></Config>

  <Config Name="PHX_HOST" Target="PHX_HOST" Default="localhost"
          Description="Public hostname for the server (e.g. cromulent.example.com). Used for WebSocket URLs."
          Type="Variable" Display="always" Required="true" Mask="false"></Config>

  <!-- Data volume -->
  <Config Name="Uploads" Target="/app/priv/static/uploads" Default="/mnt/user/appdata/cromulent/uploads"
          Description="Persistent storage for user avatar uploads."
          Type="Path" Display="always" Required="true" Mask="false">/mnt/user/appdata/cromulent/uploads</Config>
</Container>
```

**Config Type values:** `Port`, `Path`, `Variable`, `Device` — these are the four accepted types for CA template Config elements.

**Config Mode for Port:** `tcp` or `udp`.

**Config Mode for Path:** `rw` (read-write) or `ro` (read-only).

**Mask="true":** Hides the value in the Unraid UI (use for secrets/passwords).

**Source:** [Unraid Docker Template XML Schema forum post](https://forums.unraid.net/topic/38619-docker-template-xml-schema/), [selfhosters.net templating guide](https://selfhosters.net/docker/templating/templating/) — MEDIUM confidence (official wiki not directly fetchable; schema established from multiple community examples).

### Template Hosting Requirements

| Requirement | Details |
|-------------|---------|
| Hosting location | Public GitHub repository (can be the main cromulent repo in `unraid/` subdir, or a separate `-templates` repo) |
| File location | `unraid/cromulent.xml` — path must match `<TemplateURL>` in the XML |
| Icon | PNG, ideally 128x128 or 256x256, hosted at a stable raw GitHub URL |
| Submission to CA | Create a support thread on [forums.unraid.net](https://forums.unraid.net), then submit via CA submission form; alternatively, users can load a private template directly without CA listing |

### Prerequisite: Docker Image on a Registry

The template's `<Repository>` field must point to a publicly pullable Docker image. The Cromulent project needs a `Dockerfile` and either:
- **GitHub Container Registry (ghcr.io)** — free for public repos, integrates with GitHub Actions via `GITHUB_TOKEN`
- **Docker Hub** — traditional option, requires Docker Hub account

**Recommendation: ghcr.io** — no separate account needed, `GITHUB_TOKEN` authenticates automatically in GitHub Actions. This means the release workflow needs a Docker build/push job in addition to the Electron build jobs.

**Source:** [GitHub Container Registry docs](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry) — HIGH confidence.

### Docker Image Build: No New Elixir Dependencies

The existing app works with `mix release` + a multi-stage Dockerfile. Standard Phoenix release Dockerfile pattern:

```dockerfile
FROM elixir:1.18.2-alpine AS build
# ... mix deps.get, assets.deploy, mix release ...

FROM alpine:3.19 AS app
COPY --from=build /app/_build/prod/rel/cromulent ./
CMD ["/app/bin/cromulent", "start"]
```

**Key consideration:** The `priv/static/uploads/avatars/` directory must exist and be writable in the container. Map it as a Docker volume so avatar files persist across container restarts (already reflected in the Unraid template Config above).

---

## Supporting Libraries Summary

### New Elixir Dependencies (add to mix.exs)

None required for the core feature set. If avatar resizing is added:

```elixir
# Only add if resize/thumbnail generation is needed in scope
{:image, "~> 0.63"}
```

### New npm Dependencies (electron-client/package.json)

```json
{
  "devDependencies": {
    "electron": "^40.4.0",
    "electron-builder": "^26.0.0"
  }
}
```

Remove: `"@electron/packager": "^19.0.3"`

### New Infrastructure Files (no new tools needed)

| File | Purpose |
|------|---------|
| `.github/workflows/release.yml` | GitHub Actions matrix build for Linux AppImage + Windows NSIS |
| `Dockerfile` | Multi-stage Phoenix release image for self-hosting |
| `unraid/cromulent.xml` | Unraid CA template |
| `unraid/icon.png` | App icon for Unraid CA listing |

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| Phoenix LiveView built-in uploads | Waffle hex package | Waffle is designed for S3/cloud backends; local disk upload needs no abstraction layer, just `File.cp!/2` |
| Phoenix LiveView built-in uploads | Arc hex package | Arc is deprecated; Waffle is its successor; same objection applies |
| electron-builder ^26 | Stay with @electron/packager | Packager does not produce NSIS installer or AppImage; no GitHub Releases integration; migration cost is low (one package.json change) |
| electron-builder ^26 | Electron Forge | Forge is a higher-level tool (wraps builder); adds complexity without benefit for this use case; builder's direct control is preferable |
| ghcr.io for Docker registry | Docker Hub | ghcr.io uses the same `GITHUB_TOKEN` already in the workflow; no separate account credentials needed |
| Tag-triggered Actions release | Branch-triggered | Tag-based gives explicit release control; avoids accidental release from every merge to main |
| `image` hex (vix/libvips) | `mogrify` (ImageMagick wrapper) | Mogrify requires ImageMagick installed in the Docker container, inflating image size; image/vix ship prebuilt libvips binaries via NIF |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `arc` hex package | Deprecated, unmaintained since 2018 | Phoenix LiveView `allow_upload/3` built-in |
| `waffle` hex package | S3/cloud abstraction, no value for local disk | Phoenix LiveView `allow_upload/3` built-in |
| `@electron/packager` | Cannot produce NSIS installer or AppImage; Windows users expect an installer | `electron-builder` ^26 |
| `electron-forge` | Higher abstraction, still uses builder internally; adds complexity and a separate config format | `electron-builder` directly |
| Windows code signing for v1.1 | EV certs require hardware HSM or cloud service ($300-500/yr); SmartScreen warning is acceptable for self-hosted technical users | Skip signing; document workaround for users |
| Cross-compiling Windows .exe from Linux | Wine-based cross-compilation is fragile for apps with native modules (uiohook-napi) | Use `windows-latest` GitHub Actions runner |
| `mogrify` for avatar resize | Requires ImageMagick in Docker container, increases image size by ~200 MB | `{:image, "~> 0.63"}` with bundled libvips |

## Stack Patterns by Feature

**Avatar uploads (Phoenix LiveView disk storage):**
- `allow_upload/3` in `mount/3` — configures the upload field
- `<.live_file_input>` in the template — renders `<input type="file">`
- `consume_uploaded_entries/3` in `handle_event("save", ...)` — writes file to `priv/static/uploads/avatars/`
- `static_paths/0` in `cromulent_web.ex` — must include `"uploads"` for Phoenix to serve files
- Store avatar path (relative URL) in `users` table, display in `<img src={@user.avatar_url}>` everywhere

**PTT key binding config:**
- No new backend libraries needed — store binding string in user preferences table
- Electron side: read from `electron-store`, pass to `main.js` PTT manager via IPC
- Web side: store binding preference in user settings, display in settings LiveView

**GitHub Actions Electron release:**
- One workflow file, matrix strategy for OS
- Trigger on git tag push (`v*`)
- `windows-latest` runner for NSIS, `ubuntu-latest` runner for AppImage
- Artifacts uploaded to GitHub Release (electron-builder `--publish always` with `GH_TOKEN`)

**Unraid template distribution:**
- Single XML file committed to the GitHub repo
- Users can add as private CA template immediately (no CA submission required)
- Submit to CA after confirming Docker image works correctly for a few users

## Version Compatibility

| Package | Version | Compatible Electron | Notes |
|---------|---------|---------------------|-------|
| electron-builder | ^26.0.0 | 33+ (tested), 40.x expected | Uses Electron's own version detection; no manual header config needed |
| uiohook-napi | 1.5.4 | 40.x | Uses N-API (stable ABI); should not need recompilation across Electron major versions. Verify Windows prebuilt available. |
| electron-localshortcut | 3.2.1 | Any | Pure JS, no native code |
| electron-store | 11.0.2 | Any | Pure JS |
| Phoenix LiveView uploads | 1.0.x (current) | N/A (server) | No version delta; built-in since 0.14 |

## Sources

- [Phoenix LiveView Uploads — hexdocs.pm](https://hexdocs.pm/phoenix_live_view/uploads.html) — HIGH confidence, official docs
- [electron-builder GitHub](https://github.com/electron-userland/electron-builder) — HIGH confidence, official repo
- [electron-builder documentation](https://www.electron.build/) — HIGH confidence, official docs
- [Electron Builder Action — GitHub Marketplace](https://github.com/marketplace/actions/electron-builder-action) — HIGH confidence
- [Electron code signing docs](https://www.electronjs.org/docs/latest/tutorial/code-signing) — HIGH confidence
- [elixir-image/image GitHub](https://github.com/elixir-image/image) — MEDIUM confidence (docs only)
- [vix Hex.pm](https://hex.pm/packages/vix) — MEDIUM confidence (Hex registry listing)
- [Unraid Docker Template XML Schema](https://forums.unraid.net/topic/38619-docker-template-xml-schema/) — MEDIUM confidence (forum post, established community standard)
- [selfhosters.net Unraid templating guide](https://selfhosters.net/docker/templating/templating/) — MEDIUM confidence (community guide)
- [uiohook-napi npm](https://www.npmjs.com/package/uiohook-napi) — MEDIUM confidence (npm metadata, prebuilt status unverified)

---
*Stack research for: Cromulent v1.1 — avatars, cross-platform Electron builds, Unraid CA template*
*Researched: 2026-03-04*
