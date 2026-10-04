# Codex Routes Continuity

## Current state — 2026-10-03

- Fixed the unwanted Settings window on app launch. `CodexRouteApp` now uses a
  SwiftUI `Settings` scene, which macOS does not create as the app's default
  window; the tray popover's Settings command explicitly invokes
  `openSettings()` instead.
- Model catalogs now derive `input_modalities` from each selected model's
  live Ollama `POST /api/show` capabilities on the route being applied. Only a
  model advertising `vision` receives `["text", "image"]`; text-only models
  receive `["text"]`. Capability lookup is fail-closed before local Codex
  configuration is written. Studio setup starts the loopback tunnel, performs
  that lookup, then provisions the Studio routing file.
- Validation for these changes: standard Xcode tests passed (7 tests, 2
  opt-in tests skipped); the live Studio integration suite passed (7 tests, 0
  failures) and asserted Studio Qwen receives image input. The integration
  cleanup restored the prior local and Studio files. `graphify extract .
  --code-only --no-cluster --force` completed with 204 nodes and 358 edges;
  production build and `codesign --verify --deep --strict CodexRoute.app`
  passed. The rebuilt app was not launched or used to restart ChatGPT/Codex.

- Fixed a catalog-label defect observed in the Codex desktop picker: selected
  Ollama slugs could inherit a stale `display_name` (for example,
  `glm-5.3:cloud`) from an Ollama catalog template. `RouteService.makeCatalog`
  now always assigns each selected slug its own label, preserving the friendly
  Studio-Qwen name only for `qwen3.6:35b-a3b-coding-mxfp8`.

- Fixed a routing-catalog bug discovered from the user's 503: when a selected
  model set omitted the baseline `auto_review_fallback_model` (for example
  `gemma4:31b:cloud`), Ollama rejected every request before model dispatch.
  `RouteService.makeRouting` now rewrites the fallback to a selected model and
  the integration test asserts that it is present in the published catalog.
- The app was rebuilt and codesign verification passed. Full Xcode tests passed
  (4 tests, 0 failures), including the opt-in Studio pre-restart integration
  test (4 tests, 0 failures); the test restored the user's local and Studio
  state afterward. Graphify was refreshed to 195 nodes and 324 edges.

- The project is a Swift Package that builds `CodexRoute.app`, a signed,
  menu-bar-only macOS application.
- The Mac Studio is reachable at `100.111.82.14`. Its Ollama `/api/version`
  endpoint is reachable through a temporary SSH loopback tunnel from local
  `127.0.0.1:11435` to Studio `127.0.0.1:11434`.
- Studio's special `/api/codex/v1` endpoint requires
  `~/.codex/ollama-launch-codex-routing.json`. It was missing on the Studio,
  which caused the observed HTTP 503. `RouteService.provisionStudioRouting`
  now prepares and backs up that file during Studio setup.
- The direct Studio canary is currently active and user-verified: the desktop
  picker selected `qwen3.6:35b-a3b-coding-mxfp8` and received a successful
  HTML response through `127.0.0.1:11435/api/codex/v1`. Its exact pre-existing
  state is preserved by the `.bak` files alongside the three active files.
- The app has been rebuilt and launched after the current source changes.
- A restart failure exposed a design defect in the prior app: it prepended a
  global `openai_base_url` override to the real `config.toml`. That redirected
  the signed-in desktop provider and could leave Codex unable to start. A
  subsequent desktop restart proved that using only
  `ollama-launch.config.toml` is not a replacement: it is a Codex CLI profile,
  not the desktop model-publication hook. The app must not claim that this
  profile alone publishes Studio models.
- The duplicate restart alerts are consolidated into one application-modal
  confirmation. The legacy auto-opened, long scrollable setup window was
  removed; the menu-bar popover is the only normal workflow surface.

## Current UX direction

The user needs the first-click experience to be self-contained, not merely
compact. It mirrors Ollama's ChatGPT row and switch, then reveals a blue
Local/Studio selector and the next actions directly: select visible models,
start/check Studio tunnel, apply, restart, and restore defaults. Open and
Settings remain available, but must not be required to discover these actions.

## Next work

1. Manually verify the native `NSStatusItem` popover behavior. It replaced
   `MenuBarExtra` so one click consistently opens the Ollama-style panel.
2. The direct Studio canary is staged and awaiting the user's explicit
   ChatGPT/Codex restart. It uses the same active local Ollama integration
   shape, but replaces only the endpoint and Hermes selection with Studio
   Qwen. Do not make additional configuration changes before the user checks
   the desktop picker and sends one test message.

## Validation record

- The app now uses the proven active-file method: it preserves immutable
  adjacent `.bak` files, writes the complete selected-Ollama-plus-native
  catalog to `ollama-launch-models.json`, writes the matching routing JSON
  locally and on Studio, then writes a small managed block in active
  `config.toml` pointing at the SSH-loopback Codex API. Restore copies the
  adjacent baseline files back and never edits those `.bak` files.
- Studio runtime controls now live only in Settings. Context is constrained to
  64K by the project safety contract; keep-alive accepts safe values such as
  `60m` or `1h`. Applying them persists the Studio launch-agent environment
  after a one-time `.codexroute.bak`, then restarts Studio Ollama only after an
  in-app confirmation. That destructive service restart was intentionally not
  exercised by automated tests.
- Full Xcode tests and the opt-in live Studio pre-restart integration test
  passed after the refactor (4 tests, 0 failures). The live test snapshots and
  restores exact local and Studio routing contents around tunnel/provisioning,
  active configuration, and catalog publication. Release build/signing passed;
  Graphify refreshed to 195 nodes and 324 edges.

- `graphify extract . --code-only --no-cluster --force` succeeded after adding
  `.graphifyignore`: 155 nodes and 223 edges, with `RouteStore` and
  `RouteService` the main coordination nodes. Generated build artifacts are
  excluded.
- `swift test` previously passed: 2 tests, 0 failures.
- Release build and `codesign --verify --deep --strict CodexRoute.app`
  previously passed.
- After the direct-popover workflow update, Graphify was refreshed to 167 nodes
  and 253 edges; tests and release signing again passed.
- The direct popover now has no constrained scroll region and uses a 700-point
  expanded height so tunnel, apply, restart, and restore actions remain visible.
  The app-owned `Process` tunnel integration test passed (3 tests, 0 failures),
  including Studio reachability through `127.0.0.1:11435/api/version`.
- Graphify was refreshed after that change: 169 nodes and 260 edges.
- Root cause of the tray button failure: `prepareStudioConnection()` tried a
  direct clear-text HTTP `URLSession` preflight to the Tailnet IP, which macOS
  blocked before SSH could start. The direct preflight was removed; it now
  starts SSH first and validates Studio through the same loopback path Codex
  uses. The complete app-method pre-restart integration test passed: 4 tests,
  0 failures, including configuration apply and restoration. The native config
  was confirmed restored afterward. Graphify was refreshed: 173 nodes and 271
  edges.
- After the restart failure, full Studio integration testing was rerun against
  the safe launch-profile design: tunnel start, Studio routing provision,
  launch profile write, loopback `/api/version` and `/v1/models` checks, and
  restore. All 4 tests passed; the test asserts `config.toml` is byte-for-byte
  unchanged across apply and restore. The release app was signed and Graphify
  refreshed to 186 nodes and 301 edges.
- Interactive desktop validation subsequently falsified the launch-profile
  assumption: after a successful restart, only native OpenAI subscription
  models were visible. That outcome is safe but not a working Studio route.
  The legacy setup window was removed and the app was rebuilt, signed, and
  relaunched; Graphify was refreshed to 183 nodes and 283 edges.
- The user's verified local Hermes success corrected the earlier eligibility
  conclusion: locally installed non-cloud models do work through the Ollama
  ChatGPT integration. The staged Studio canary therefore keeps the exact
  Ollama-generated schema and only changes `config.toml` from Hermes/local
  endpoint to Studio-Qwen/SSH-loopback. Adjacent backups were created as
  `config.toml.bak`, `ollama-launch-models.json.bak`, and
  `ollama-launch-codex-routing.json.bak`; Studio's absent original routing
  file is represented by an adjacent zero-byte `.bak` sentinel.
- Pre-restart validation passed: Codex strict configuration validation loaded
  the config, the loopback returned the Studio Ollama version, and a minimal
  `POST /api/codex/v1/responses` for `qwen3.6:35b-a3b-coding-mxfp8` completed
  with HTTP 200. Desktop UI selection remains the pending acceptance check.
- The Ollama UI's Restart ChatGPT action was observed to regenerate the active
  integration files from its own local selection, overwriting the Studio
  canary with Hermes/local endpoint values. The canary was then reapplied
  directly to only the active files; all adjacent `.bak` files remain
  byte-for-byte unchanged. For the pending test, the user must quit and reopen
  ChatGPT/Codex manually rather than using Ollama's restart button.
