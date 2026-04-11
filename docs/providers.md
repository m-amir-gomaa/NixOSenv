# OpenClaude Provider & Model Reference

OpenClaude uses `CLAUDE_CODE_USE_OPENAI=1` plus three env vars to route to any
OpenAI-compatible endpoint. No patching, no YAML registry — just env vars.

```
CLAUDE_CODE_USE_OPENAI=1      # enable OpenAI-compat mode
OPENAI_API_KEY=<key>          # provider API key
OPENAI_BASE_URL=<url>         # provider base URL  (e.g. https://api.groq.com/openai/v1)
OPENAI_MODEL=<model-id>       # model ID as the provider expects it
```

These are set permanently in `home.nix` → `home.sessionVariables`.
The `oc-*` aliases override them per-invocation.

---

## Default Provider

| Variable | Value |
|---|---|
| `OPENAI_API_KEY` | `$GEMINI_API_KEY` |
| `OPENAI_BASE_URL` | `https://generativelanguage.googleapis.com/v1beta/openai` |
| `OPENAI_MODEL` | `gemini-2.5-flash` |

Launch: `oc` or `openclaude`

---

## All Configured Providers & Aliases

### Gemini (Google)

| Alias | Model |
|---|---|
| `oc` / `oc-gemini-flash` | `gemini-2.5-flash` |
| `oc-gemini-pro` | `gemini-2.5-pro` |

Base URL: `https://generativelanguage.googleapis.com/v1beta/openai`  
Key env var: `GEMINI_API_KEY`

---

### Groq

| Alias | Model |
|---|---|
| `oc-groq` | `llama-3.3-70b-versatile` |
| `oc-groq-qwen` | `qwen/qwen3-32b` |
| `oc-groq-fast` | `llama-3.1-8b-instant` |
| `oc-groq-llama4` | `meta-llama/llama-4-scout-17b-16e-instruct` |
| `oc-groq-cmpd` | `groq/compound` |
| `oc-gpt-oss` | `openai/gpt-oss-120b` |
| `oc-gpt-oss-sm` | `openai/gpt-oss-20b` |

Base URL: `https://api.groq.com/openai/v1`  
Key env var: `GROQ_API_KEY`

---

### Cerebras

| Alias | Model |
|---|---|
| `oc-cerebras` | `qwen-3-235b-a22b-instruct-2507` |
| `oc-cerebras-llm` | `llama3.1-8b` |

Base URL: `https://api.cerebras.ai/v1`  
Key env var: `CEREBRAS_API_KEY`

---

### OpenRouter (free tier)

| Alias | Model |
|---|---|
| `oc-nemotron` | `nvidia/llama-3.1-nemotron-70b-instruct` |
| `oc-nemo-nano` | `nvidia/nemotron-nano-9b-v2:free` |
| `oc-gemma-27b` | `google/gemma-3-27b-it:free` |
| `oc-gemma-12b` | `google/gemma-3-12b-it:free` |
| `oc-minimax` | `minimax/minimax-m2.5:free` |
| `oc-glm` | `z-ai/glm-4.5-air:free` |
| `oc-trinity` | `arcee-ai/trinity-large-preview:free` |
| `oc-lfm` | `liquid/lfm-2.5-1.2b-instruct:free` |

Base URL: `https://openrouter.ai/api/v1`  
Key env var: `OPEN_ROUTER_API_KEY`

---

## Switching Providers

### Per-invocation (one-shot)

Use an alias. Example:

```bash
oc-groq                  # launch with Groq Llama 3.3 70B
oc-cerebras              # launch with Cerebras Qwen 3 235B
```

### For the current shell session

```bash
export OPENAI_API_KEY="$GROQ_API_KEY"
export OPENAI_BASE_URL="https://api.groq.com/openai/v1"
export OPENAI_MODEL="llama-3.3-70b-versatile"
oc
```

### Permanently (default provider)

Edit `home.nix` → `home.sessionVariables`:

```nix
OPENAI_API_KEY  = secrets.groq_api_key;
OPENAI_BASE_URL = "https://api.groq.com/openai/v1";
OPENAI_MODEL    = "llama-3.3-70b-versatile";
```

Then run `nr` to rebuild.

### Inside an active openclaude session

Use the `/provider` slash command to check the current provider and get switching instructions.  
Use the `/model` slash command to inspect or change the active model.

---

## Adding a New Provider

1. Get the provider's OpenAI-compatible base URL and an API key.
2. Add the key to `secrets.nix` (source) and reference it in `home.nix`:
   ```nix
   MY_NEW_KEY = secrets.my_new_key;
   ```
3. Add an alias in `home.nix` → `shellAliases`:
   ```nix
   oc-myprovider = ''OPENAI_API_KEY="$MY_NEW_KEY" OPENAI_BASE_URL="https://api.myprovider.com/v1" OPENAI_MODEL="model-id" openclaude'';
   ```
4. Run `nr`.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `400 Bad Request` | Wrong model ID for the provider | Check the provider's model list |
| `401 Unauthorized` | Wrong key env var | Verify `echo $OPENAI_API_KEY` inside the shell |
| `max_completion_tokens` error | Provider doesn't support that param | Known Mistral issue — use a different provider |
| Empty response / hangs | Free-tier rate limit | Switch to a different free alias or wait |
