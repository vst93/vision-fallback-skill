---
name: vision-fallback
description: Fallback vision reasoning via Volcengine Ark (doubao) API. Use when the primary vision model fails to interpret an image (empty/unknown output, low confidence, or user-reported failure).
---

# vision-fallback

> Calls the Volcengine Ark (doubao) vision API — NOT OpenRouter. Only credential
> needed: `ARK_API_KEY`.

## Trigger

Use when ANY holds:

- vision output empty/null, or says "unknown" / "cannot determine"
- vision confidence < 0.5 (if available)
- OCR text exists but primary model fails to interpret it
- user says the image is not understood / result is wrong

Otherwise do NOT use this skill.

## Input

`image` (required: file path / URL / data URL), `ocr_text`, `failure_reason`,
`primary_model_output` (all optional).

## Workflow

1. `./scripts/call-api.sh "$IMAGE" "$OCR_TEXT" "$FAILURE_REASON" "$PRIMARY_OUTPUT"`
   — resolves `ARK_API_KEY` itself, converts the image to a data URL, assembles
   the payload, and POSTs. See [references/configuration.md](references/configuration.md)
   for key-resolution order.
2. Parse `choices[0].message.content` → structured JSON. Schema in
   [references/output-format.md](references/output-format.md).
3. If still insufficient → escalate to a stronger model (GPT-4o / Claude
   Vision); do NOT retry this skill. Full rules in
   [references/constraints.md](references/constraints.md).

API endpoint/body/model note: [references/api-reference.md](references/api-reference.md).
