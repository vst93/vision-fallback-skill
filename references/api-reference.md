# API Reference

## Endpoint

The skill calls the standard OpenAI-compatible `/chat/completions` endpoint.
The actual URL depends on `VISION_PROVIDER`:

| Provider | Endpoint |
|----------|----------|
| `ark` (default) | `https://ark.cn-beijing.volces.com/api/plan/v3/chat/completions` |
| `openai` | `https://api.openai.com/v1/chat/completions` |

Override with `VISION_BASE_URL` (the skill appends `/chat/completions`).

## Headers

```
Authorization: Bearer <API_KEY>
Content-Type: application/json
```

## Request body

`content` is an ARRAY mixing text + `image_url` - this is mandatory for
multimodal input. This is the standard OpenAI vision format, compatible with
both Volcengine Ark and any OpenAI-compatible provider.

```json
{
  "model": "<MODEL>",
  "messages": [
    {
      "role": "system",
      "content": "You are a multimodal vision reasoning fallback model. Your job is to interpret images when the primary model fails. Return strict, structured JSON only."
    },
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "Analyze the attached image and reconstruct its meaning.\n\nFailure reason:\n{{failure_reason}}\n\nOCR text (if any):\n{{ocr_text}}\n\nPrimary model output:\n{{primary_model_output}}\n\nTasks:\n1. Describe what is shown in the image\n2. Extract UI elements / objects / text\n3. Reconstruct layout or structure\n4. Infer missing parts if needed (mark clearly as inferred)\n\nRespond as JSON with keys: summary, objects, text_detected, ui_structure, inferred_elements, uncertainty_notes."
        },
        {
          "type": "image_url",
          "image_url": { "url": "{{IMAGE_URL}}" }
        }
      ]
    }
  ],
  "temperature": 0.2
}
```

A ready-to-fill template lives at
[../assets/payload-template.json](../assets/payload-template.json).
The `{{MODEL}}` placeholder is substituted at runtime from `VISION_MODEL`
(defaults: `doubao-seed-2.0-lite` for ark, `gpt-4o-mini` for openai).

## Model note

| Provider | Default model | Notes |
|----------|--------------|-------|
| `ark` | `doubao-seed-2.0-lite` | Volcengine Ark / doubao |
| `openai` | `gpt-4o-mini` | OpenAI-compatible; override with `VISION_MODEL` |

The Volcengine Ark API is fully OpenAI-compatible (same `/chat/completions`
endpoint, same request/response schema), so the same payload template works
for both providers.

## Image payload preparation

The API requires the image inside the message `content` array as an
`image_url` part. Convert local files to a base64 data URL first:

```bash
IMG="$IMAGE_PATH"
MIME=$(file -b --mime-type "$IMG")
B64=$(base64 -w0 "$IMG")
IMAGE_URL="data:${MIME};base64,${B64}"
```

If `image` is already an `http(s)://` URL or a `data:` URL, use it directly.

## Minimal curl example

```bash
curl -sS "$VF_ENDPOINT" \
  -H "Authorization: Bearer $VF_API_KEY" \
  -H "Content-Type: application/json" \
  -d @payload.json
```
