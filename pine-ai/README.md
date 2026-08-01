# 🧭 KindredAgent — your own "Pine AI"

A personal AI assistant that makes real phone calls for you — negotiating bills,
canceling subscriptions, disputing charges, and waiting on hold. This is a
starter foundation with all three layers wired up.

> **KindredAgent is a placeholder name.** Rename it to whatever you want (search/replace
> "KindredAgent" and the 🧭 emoji).

## What's here

```
pine-ai/
├── web/                  Static site — works on GitHub Pages today
│   ├── index.html        Marketing landing page + waitlist
│   ├── app.html          Live demo: Claude plans & role-plays a call (the "brain")
│   └── assets/           styles + demo logic
├── server/               Backend MVP — places REAL calls (Claude + Twilio)
│   ├── src/index.js      Express server + Twilio call flow
│   ├── src/brain.js      Claude wrapper (plans + drives the conversation)
│   ├── src/prompts.js    The on-call system prompt
│   ├── src/stream.js     Natural-voice upgrade path (Deepgram + ElevenLabs) — skeleton
│   └── .env.example      All the keys you'll need
└── docs/
    ├── ARCHITECTURE.md   How the four pieces fit together
    └── ROADMAP.md        Phased plan + realistic costs + legal checklist
```

## Try it in 2 minutes (no accounts needed for the demo)

1. Open `web/app.html` in a browser (or via any static server).
2. Click **API key**, paste an [Anthropic key](https://console.anthropic.com/).
3. Type a task like *"Cancel my gym membership"* → watch Claude plan the call,
   write the opening script, and role-play the rep.

The demo runs the brain **only** — no phone calls. It calls Claude directly from
the browser for convenience; **never** ship a real app that way (your key would be
exposed). The `server/` proxies it properly.

## Make a real phone call (Phase 1)

```bash
cd pine-ai/server
npm install
cp .env.example .env      # fill in Anthropic + Twilio keys
npx ngrok http 3000       # in another terminal; paste the https URL as PUBLIC_BASE_URL
npm start
```

Then start a call:

```bash
curl -X POST http://localhost:3000/calls \
  -H "Content-Type: application/json" \
  -d '{"to":"+1YOURNUMBER","task":"Ask what time the store closes today","context":""}'
```

KindredAgent dials, speaks, listens, and prints a summary when the call ends. Start by
calling **your own phone** or a friendly business — see the legal checklist in
`docs/ROADMAP.md` before calling anyone else.

## Deploy the landing page
The `web/` folder is plain static HTML. Point GitHub Pages (or Netlify/Vercel) at
it and it's live. The waitlist form is a stub — wire it to your backend or an
email tool (Formspree, ConvertKit, etc.) before launch.

## Where to go next
`docs/ROADMAP.md` has the full phased plan, ballpark costs (spoiler: ~$0.15–0.40
per call), and the legal/consent items you must handle before real users.
