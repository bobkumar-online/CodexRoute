# Codex Routes — Project Instructions

## Purpose

`CodexRoute` is a local macOS menu-bar application. It lets Bob switch the
ChatGPT/Codex desktop client between native ChatGPT subscription routing,
MacBook-local Ollama, and a Mac Studio Ollama server reached through an SSH
loopback tunnel. It must preserve native OpenAI subscription models in every
Ollama-enabled mode.

## UX contract

The first click on the menu-bar item must mirror Ollama's own compact menu:

- A **ChatGPT** row with a single `Use Ollama models in ChatGPT` toggle.
- `Open Codex Routes` for the guided configuration window.
- `Settings` for connection/advanced settings.
- `Quit Codex Routes`.

When the ChatGPT switch is on, show a compact Local/Studio host selector
beneath it, with the selected host visibly blue. The same popover must then
show a numbered, directly actionable workflow: model visibility, tunnel
start/check for Studio, apply, restart, and restore-native-defaults. Do not
require the user to infer that these actions live in a separate window.

## Routing and safety invariants

- Never replace or hide native ChatGPT subscription models.
- Never change `~/.codex/config.toml` without first preserving the immutable
  baseline and a timestamped backup in `~/.codex/codex-route/`.
- Studio mode uses only `127.0.0.1:<local-port>` forwarded by SSH to the
  Studio's `127.0.0.1:11434`; never expose a new network listener.
- Before a Studio route is applied, verify Tailscale reachability, establish
  the tunnel, and provision the Studio-side
  `~/.codex/ollama-launch-codex-routing.json` with a reversible backup.
- `Restore native defaults` restores both the local Codex baseline and the
  Studio routing-file state managed by this app.
- A connection check must not modify Codex configuration or require a restart.

## Model policy

- Studio coding model: `qwen3.6:35b-a3b-coding-mxfp8`.
- Keep the Studio model's advertised context window at or below 64K.
- Default native smoke-test model: `gpt-5.6-luna` at `low` effort.
- Do not introduce OpenAI API-key billing or LiteLLM into this desktop route.

## Development workflow

1. Read `.pm/continuity.md` before changing behavior.
2. Refresh project architecture after material source changes:
   `graphify extract . --code-only --no-cluster --force`.
3. Keep generated `.build/`, `CodexRoute.app/`, and `graphify-out/` out of
   source analysis and version control.
4. Build and test with full Xcode:
   `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --scratch-path /tmp/codex-route-swift-tests`
   followed by `zsh scripts/build-app.sh` and
   `codesign --verify --deep --strict CodexRoute.app`.
   Before shipping a Studio tunnel or setup change, also run:
   `CODEX_ROUTE_STUDIO_INTEGRATION=1 swift test --scratch-path /tmp/codex-route-swift-tests`.
   This test must prove the pre-restart flow: tunnel start, Studio routing-file
   provision, managed Codex configuration write, loopback verification, and
   restoration of the original configuration.
5. Update `.pm/continuity.md` after each meaningful behavior or routing change.

## Boundaries

- Do not send model prompts, credentials, or user data to external providers
  without explicit user authorization.
- Do not terminate/restart ChatGPT/Codex without an explicit in-app
  confirmation.
- Preserve user changes and unrelated files in `~/.codex`.
