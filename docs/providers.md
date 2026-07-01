# OpenCode Provider & Model Reference

OpenCode (`opencode`) is the AI coding agent. It is installed globally via npm (`opencode-ai` package) and configured via `~/.config/opencode/config.json`.

---

## Default Provider (Local Ollama)

By default, launching `ai` connects to your local Ollama server with `qwen2.5-coder:14b`.

| Alias          | Model                    | Backend                      |
|----------------|--------------------------|------------------------------|
| `ai` / `ai-qwen` | `qwen2.5-coder:14b`    | Ollama (localhost:11434)     |
| `ai-qwen-sm`   | `qwen2.5-coder:7b`       | Ollama                       |
| `ai-deepseek`  | `deepseek-r1:14b`        | Ollama                       |
| `ai-deepseek-sm` | `deepseek-r1:8b`       | Ollama                       |
| `ai-llama`     | `llama3.2:latest`        | Ollama                       |
| `ai-mistral`   | `mistral:latest`         | Ollama                       |
| `ai-gemma`     | `gemma-4-E4B-it-GGUF`   | LM Studio (localhost:1234)   |
| `ai-gemini`    | `gemini-2.5-flash`       | Google Gemini API            |
| `ai-groq`      | `llama3-70b-8192`        | Groq API                     |

The same models are available as `oc-*` shell functions (e.g. `oc-qwen`, `oc-deepseek`, `oc-gemini`).

---

## Local Providers

### 1. Ollama (Background Service)

Ollama is enabled globally as a systemd service, running at `http://localhost:11434`.

```bash
ollama pull qwen2.5-coder:14b   # pull model first if needed
ai                               # launch opencode with default model
```

### 2. LM Studio (Desktop GUI & Server)

LM Studio provides a visual model downloader and local server.

1. Launch under Wayland: `lmstudio`
2. Download a GGUF model in the GUI.
3. Go to **Developer Tab → Start Server** (port 1234).
4. Launch: `ai-gemma`

---

## Cloud Providers

API keys are stored in `secrets.nix` (decrypted from `secrets.nix.age`) and written into `~/.config/opencode/config.json` at setup time.

| Alias       | Model               | Provider      |
|-------------|---------------------|---------------|
| `ai-gemini` | `gemini-2.5-flash`  | Google Gemini |
| `ai-groq`   | `llama3-70b-8192`   | Groq          |

---

## How it Works

OpenCode reads `~/.config/opencode/config.json` for all provider credentials,
model definitions, MCP server configurations, and agent prompts.

The `model` field uses the format `provider/model-id`, e.g.:
- `ollama/qwen2.5-coder:14b`
- `google/gemini-2.5-flash`
- `groq/llama3-70b-8192`

---

## Switching Providers at Runtime

Inside an active `opencode` TUI session:
- Use `/model` to switch models on the fly.
- Pass `-m provider/model` on the command line to start with a specific model.
