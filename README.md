# vision-fallback

[![skills.sh](https://skills.sh/b/vst93/vision-fallback-skill)](https://skills.sh/vst93/vision-fallback-skill)

Fallback multimodal vision reasoning skill for AI coding agents. Activates
**only when the primary vision model fails** to interpret an image (empty /
unknown output, low confidence, or user-reported failure), and performs
structured image understanding for UI screenshots, OCR, terminal outputs,
mobile apps, and layout reconstruction.

It calls the **Volcengine Ark (doubao) vision API** and returns structured
JSON (`summary`, `objects`, `text_detected`, `ui_structure`,
`inferred_elements`, `uncertainty_notes`).

> ⚠️ **See the Prerequisites section before installing.** This skill requires a
> Volcengine `ARK_API_KEY`, which is primarily available in mainland China.

---

## ⚠️ Prerequisites & Region Notice

- This skill calls the **Volcengine Ark (doubao) vision API**
  (`https://ark.cn-beijing.volces.com`), hosted on Volcengine in **mainland
  China**.
- It does **NOT** use OpenRouter, OpenAI, or Anthropic. The only credential it
  needs is `ARK_API_KEY`, issued by Volcengine (火山引擎).
- **Users outside mainland China** may be unable to register a Volcengine
  account or obtain an `ARK_API_KEY`, and may experience network latency /
  reachability issues to the `ark.cn-beijing.volces.com` endpoint. Please
  confirm you can access Volcengine before installing.
- The API key is read from the `ARK_API_KEY` environment variable or
  `~/.env_vars`. The skill never logs or prints its value.

If you need a globally available fallback instead, consider swapping the
endpoint in `references/api-reference.md` for an OpenAI / Anthropic vision
endpoint.

---

## Install

### Generic (Claude Code, Cursor, Windsurf, Codex, …)

```bash
npx skills add vst93/vision-fallback-skill
```

Replace `vst93` with the GitHub owner of this repository.

> ℹ️ `npx skills add` installs into the harness's own skill directory (e.g.
> `~/.claude/skills/`). Other harnesses that scan different paths will **not**
> auto-discover it — see the harness-specific notes below.

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

It checks shell deps, `ARK_API_KEY` resolution, and endpoint reachability, and
exits non-zero with an actionable message if anything is missing. Run this once
before relying on the skill — if `check.sh` fails, the API call will fail too.

Compatible with any agent harness that supports the
[Agent Skills standard](https://agentskills.io/specification)
(Claude Code, Cursor, Windsurf, Codex, pi, etc.).

## Configure

Set your Volcengine API key:

```bash
# Option A: environment variable (preferred)
export ARK_API_KEY=xxxxxxxxxxxxxxxx

# Option B: dotenv file
echo 'ARK_API_KEY=xxxxxxxxxxxxxxxx' >> ~/.env_vars
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
│   ├── check.sh                  # Preflight: deps + ARK_API_KEY + endpoint
│   ├── resolve-key.sh            # ARK_API_KEY resolution (env → dotenv, fail-fast)
│   └── call-api.sh               # Image → data URL + payload + curl POST
├── references/                   # Loaded on demand (progressive disclosure)
│   ├── configuration.md          # Key resolution order, ~/.env_vars format
│   ├── api-reference.md          # Endpoint, headers, body schema, model note
│   ├── output-format.md          # Response JSON schema
│   └── constraints.md            # Retry / escalation rules
└── assets/
    └── payload-template.json     # Request body template (jq-rendered)
```

## Constraints

- Only triggered when primary vision fails.
- Only one fallback call per image (no retry loop).
- If output is still insufficient → escalate to a stronger vision model
  (e.g. GPT-4o / Claude Vision). See
  [`references/constraints.md`](references/constraints.md).

## License

[MIT](LICENSE)
