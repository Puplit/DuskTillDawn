-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.

PO = PO or {}

PO.secrets = {
    Webhooks = {
        anonymousLetters = '', -- Discord webhook for anonymous-letter copies; '' = off
    },
}
