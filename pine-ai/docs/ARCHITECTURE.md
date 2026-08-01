# KindredAgent — Architecture

KindredAgent is a personal AI assistant that makes real phone calls on your behalf. This
is the same shape as products like Pine AI. There are four moving parts.

```
   You ──▶ App / Web ──▶ Backend ──▶ Twilio ──▶ 📞 the company
                            │
                            ├─▶ Claude  (the brain: plans + decides what to say)
                            ├─▶ STT     (speech-to-text: hears the rep)
                            └─▶ TTS     (text-to-speech: gives KindredAgent a voice)
```

## 1. The brain — Claude
Claude plans the call (strategy, opening line, objection handling) and, on a live
call, produces each spoken turn in real time based on what the rep says. See
`server/src/brain.js` and `server/src/prompts.js`. The web demo (`web/app.html`)
runs *only* this layer so you can see the reasoning without any phone plumbing.

## 2. The voice layer — STT + TTS
The call is audio, but Claude works in text, so you need translation both ways:
- **Speech-to-text (STT):** turn the rep's speech into text for Claude.
- **Text-to-speech (TTS):** turn Claude's reply into speech the rep hears.

Two implementations, in increasing quality:

| Path | STT / TTS | Latency | Effort | Where |
|------|-----------|---------|--------|-------|
| **A. Twilio-native** | Twilio `<Gather>` + `<Say>` | ~1–2s per turn, robotic | Lowest | `server/src/index.js` (working) |
| **B. Media Streams** | Deepgram (STT) + ElevenLabs (TTS) over a websocket | Near real-time, natural | Higher | `server/src/stream.js` (skeleton) |

Start with A to prove the loop, then move to B for a natural voice.

## 3. The telephony layer — Twilio
Twilio places the outbound call and connects the audio to your server. Your server
returns **TwiML** (Twilio's XML) telling it to speak, listen, or hang up. Twilio
must be able to reach your server over the public internet — use `ngrok` in dev.

## 4. The app
Where you describe the task and read the result. Today that's:
- `web/index.html` — marketing landing page (static, GitHub Pages-ready)
- `web/app.html` — interactive "brain" demo
- The backend exposes `POST /calls` to start a real call and `GET /calls/:sid`
  for the summary. A real product would put a proper UI + auth in front of that.

## Request flow of a real call (Path A)
1. `POST /calls {to, task, context}` → backend starts a Twilio call.
2. Callee answers → Twilio fetches `/voice` → KindredAgent speaks its opening line.
3. `<Gather>` captures the rep's reply → Twilio posts `/gather`.
4. Backend sends the reply to Claude → speaks the next line → gathers again.
5. Claude emits `[END_CALL]` → backend hangs up → generates a summary.

## What to harden before real users
- **Secrets:** never expose the Anthropic key in the browser (the demo does, for
  convenience — see the warning in `app.js`). Always proxy through the backend.
- **State:** the backend keeps calls in memory. Use Redis/Postgres for anything real.
- **Consent & law:** call-recording and robocall rules vary by state/country
  (e.g. two-party consent, TCPA in the US). Disclose that it's an AI assistant,
  get consent to record, and don't auto-dial without permission. See ROADMAP.md.
- **Identity/authorization:** many tasks require the account holder's verification.
  KindredAgent must not impersonate the user. Decide how you'll handle verified handoff.
