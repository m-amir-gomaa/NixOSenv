# OpenClaude Provider & Model Reference (Local-Only)

OpenClaude is configured to run entirely offline and locally using **Ollama** and **LM Studio**. 

---

## Default Provider (Local Ollama)

By default, launching `oc` or `openclaude` connects to your local Ollama server using the `qwen2.5-coder:7b` model.

| Alias | Launcher Command | Target Model |
|---|---|---|
| `oc` / `claude` | `openclaude` | `qwen2.5-coder:7b` |

---

## Local Providers & Aliases

### 1. Ollama (Background Service)

Ollama is enabled globally as a systemd service. It runs in the background at `http://localhost:11434`.

* **Launcher Alias:** `oc-ollama`
* **Default Model:** `qwen2.5-coder:7b`
* **How to run:**
  1. Pull the model first if you haven't already:
     ```bash
     ollama pull qwen2.5-coder:7b
     ```
  2. Start OpenClaude:
     ```bash
     oc-ollama
     ```

---

### 2. LM Studio (Desktop GUI & Server)

LM Studio is installed globally. It provides a visual Hugging Face model downloader and developer server.

* **Launcher Alias:** `oc-lmstudio`
* **Wayland Client Alias:** `lmstudio`
* **Base URL:** `http://localhost:1234/v1`
* **How to run:**
  1. Launch the LM Studio GUI natively under Wayland:
     ```bash
     lmstudio
     ```
  2. Search for and download your target GGUF model (e.g., `Qwen2.5-Coder-7B-Instruct-GGUF`).
  3. Load the model inside the LM Studio GUI.
  4. Go to the **Developer Tab** (Server icon on the left panel) and **Start the Local Server** (typically maps to port `1234`).
  5. Start OpenClaude in your workspace directory:
     ```bash
     oc-lmstudio
     ```

---

## How it Works Under the Hood

OpenClaude uses standard environment variables to communicate with local endpoints:

```bash
CLAUDE_CODE_USE_OPENAI=1         # Tells OpenClaude to use OpenAI-compatible endpoint mapping
OPENAI_API_KEY="ollama"          # Local dummy auth key
OPENAI_BASE_URL="http://..."     # Points to local port (11434 for Ollama, 1234 for LM Studio)
OPENAI_MODEL="model-name"        # The model to target
```

These defaults are loaded automatically in your `home.sessionVariables` and can be overridden per-invocation using the aliases above.

---

## Switching Providers at Runtime

Inside an active `openclaude` terminal session:
* Use the `/provider` command to inspect, configure, or switch active provider profiles.
* Use the `/model` command to change the loaded model.
