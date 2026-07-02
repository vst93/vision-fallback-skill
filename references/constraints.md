# Constraints & Escalation

## Constraints

- Only triggered when primary vision fails.
- Only one fallback call per image (no retry loop).
- Never log or echo the value of `ARK_API_KEY`.

## Escalation

If the fallback output is still insufficient:

- Escalate to a stronger vision model (e.g. GPT-4o / Claude Vision).
- Do NOT loop this skill on the same image.

## Scope

This skill is a low-cost multimodal reasoning fallback layer for:

- UI screenshots
- terminal outputs
- mobile apps
- documents with OCR
- structured visual content
