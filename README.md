# Codex Routes

Native macOS menu-bar control for switching Codex between direct ChatGPT, local Ollama, and Studio Ollama routes.

## Build and run

```zsh
./scripts/build-app.sh
open ./CodexRoute.app
```

The first route change saves an immutable baseline in `~/.codex/codex-route/baseline/`. Every later mode change saves a timestamped snapshot under `~/.codex/codex-route/backups/`.

## Modes

- **None** restores the baseline and stops the app-owned Studio SSH tunnel.
- **Local** points the built-in Codex OpenAI provider to local Ollama's `/api/codex/v1` endpoint.
- **Studio** starts a loopback-only SSH tunnel at `127.0.0.1:11435`, then points Codex to Studio's loopback-only Codex endpoint through that tunnel.

The Studio catalog includes `qwen3.6:35b-a3b-coding-mxfp8` with a 64K context window. Native GPT/Codex models remain in the catalog; the default smoke-test model is `gpt-5.6-luna`.

Restart ChatGPT/Codex after switching modes. The app asks for confirmation before it attempts that restart.

## Safety

The app never stores a ChatGPT token, exposes a network listener, modifies Studio model files, or edits Ollama-generated artifacts. It writes only its own catalog files and the three top-level, route-related values in `~/.codex/config.toml`.
