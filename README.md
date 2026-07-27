# vision-fallback

[![skills.sh](https://skills.sh/b/vst93/vision-fallback-skill)](https://skills.sh/vst93/vision-fallback-skill)

Fallback multimodal vision reasoning skill for AI coding agents. Activates
**only when the primary vision model fails** to interpret an image (empty /
unknown output, low confidence, or user-reported failure), and performs
structured image understanding for UI screenshots, OCR, terminal outputs,
mobile apps, and layout reconstruction.

It calls an **OpenAI-compatible vision API** (`/chat/completions`) and returns
structured JSON (`summary`, `objects`, `text_detected`, `ui_structure`,
`inferred_elements`, `uncertainty_notes`).

Supports two providers out of the box:

- **Volcengine Ark (doubao)** — default, optimized for mainland China
- **OpenAI-compatible** — any provider that speaks the OpenAI Chat Completions
  API (OpenAI, OpenRouter, Azure OpenAI, vLLM, Ollama, etc.)

---

## Prerequisites

- `curl`, `jq`, `file`, `base64` installed
- An API key for your chosen provider:

| Provider | Key env var | Where to get it |
|----------|-------------|-----------------|
| `ark` (default) | `ARK_API_KEY` | Volcengine (火山引擎) |
| `openai` | `OPENAI_API_KEY` | OpenAI / any compatible provider |

Or use `VISION_API_KEY` which works for **any** provider.

> ⚠️ The default `ark` provider is hosted on Volcengine in **mainland China**.
> Users outside China may experience latency / reachability issues. Switch to
> `VISION_PROVIDER=openai` for a globally available alternative.

---

## Install

### Generic (Claude Code, Cursor, Windsurf, Codex, …)

```bash
npx skills add vst93/vision-fallback-skill
```

> ℹ️ `npx skills add` installs into the harness's own skill directory (e.g.
> `~/.claude/skills/`). Other harnesses that scan different paths will **not**
> auto-discover it - see the harness-specific notes below.

### pi (earendil-works/pi-coding-agent)

pi does **not** scan `~/.claude/skills/`. Install into one of pi's discovery
locations instead. Pick one:

```bash
# Option A: global skill dir (recommended)
git clone https://github.com/vst93/vision-fallback-skill \
  ~/.pi/agent/skills/vision-fallback

# Option B: link the repo you already have
ln -s /path/to/vision-fallback ~/.pi/agent/skills/vision-fallback
```

Or, without copying, register the path in `~/.pi/agent/settings.json`:

```json
{
  "skills": ["/path/to/vision-fallback"]
}
```

For a project-scoped skill, place it under `.pi/skills/` (trusted project) or
`.agents/skills/` in the repo root instead.

### Verify the install

After installing, confirm the skill is wired up and ready:

```bash
cd <skill-dir>
./scripts/check.sh
```

It checks shell deps, API key resolution, and endpoint reachability, and
exits non-zero with an actionable message if anything is missing. Run this once
before relying on the skill - if `check.sh` fails, the API call will fail too.

Compatible with any agent harness that supports the
[Agent Skills standard](https://agentskills.io/specification)
(Claude Code, Cursor, Windsurf, Codex, pi, etc.).

## Configure

### Doubao (default, no extra config)

```bash
export VISION_PROVIDER=ark
export ARK_API_KEY=xxxxxxxxxxxxxxxx
```

### OpenAI

```bash
export VISION_PROVIDER=openai
export OPENAI_API_KEY=sk-...
```

### Third-party OpenAI-compatible (OpenRouter, Azure, vLLM, etc.)

```bash
export VISION_PROVIDER=openai
export VISION_API_KEY=sk-...
export VISION_BASE_URL=https://your-provider.com/v1
export VISION_MODEL=your-vision-model
```

### Universal key (works for any provider)

```bash
export VISION_API_KEY=...   # overrides ARK_API_KEY / OPENAI_API_KEY
```

### Dotenv file

Instead of env vars, store keys in `~/.env_vars`:

```bash
VISION_API_KEY=xxxxxxxxxxxxxxxx
# or provider-specific:
# ARK_API_KEY=xxxxxxxxxxxxxxxx
# OPENAI_API_KEY=sk-...
```

See [`references/configuration.md`](references/configuration.md) for the full
resolution order.

## Usage

The agent loads this skill automatically when the primary vision model fails.
To trigger manually via a skill command:

```
/skill:vision-fallback
```

The core call is wrapped in a single script:

```bash
./scripts/call-api.sh "$IMAGE" "$OCR_TEXT" "$FAILURE_REASON" "$PRIMARY_OUTPUT"
```

- `IMAGE` (required): local file path, `http(s)://` URL, or `data:` URL.
- `OCR_TEXT`, `FAILURE_REASON`, `PRIMARY_OUTPUT` (optional).

## Structure

```
vision-fallback/
├── SKILL.md                      # Always loaded: trigger + workflow
├── scripts/
│   ├── check.sh                  # Preflight: deps + key + endpoint
│   ├── resolve-config.sh         # Provider/key/endpoint/model resolution
│   ├── resolve-key.sh            # (deprecated, kept for backward compat)
│   └── call-api.sh               # Image -> data URL + payload + curl POST
├── references/                   # Loaded on demand (progressive disclosure)
│   ├── configuration.md          # Provider config, key resolution order
│   ├── api-reference.md          # Endpoint, headers, body schema, model note
│   ├── output-format.md          # Response JSON schema
│   └── constraints.md            # Retry / escalation rules
└── assets/
    └── payload-template.json     # Request body template (jq-rendered)
```

## Constraints

- Only triggered when primary vision fails.
- Only one fallback call per image (no retry loop).
- If output is still insufficient -> escalate to a stronger vision model
  (set `VISION_MODEL` or switch `VISION_PROVIDER`). See
  [`references/constraints.md`](references/constraints.md).

## License

[MIT](LICENSE)
