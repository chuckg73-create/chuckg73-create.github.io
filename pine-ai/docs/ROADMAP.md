# KindredAgent — Roadmap & realistic costs

## Phased plan

### Phase 0 — Landing + brain demo ✅ (in this repo)
- Marketing page (`web/index.html`) — ship to GitHub Pages today.
- Interactive "brain" demo (`web/app.html`) — Claude plans and role-plays calls.
- **Goal:** validate interest, feel the product, collect a waitlist.

### Phase 1 — First real call (Twilio-native voice)
- Run `server/` locally with `ngrok`. Place one real call to a friendly number.
- Use Twilio `<Gather>`/`<Say>` (Path A). Robotic but end-to-end.
- **Goal:** one successful automated call (e.g. ask a store's hours).

### Phase 2 — Natural voice
- Swap in Media Streams + Deepgram (STT) + ElevenLabs (TTS) (`stream.js`).
- Add barge-in (let the rep interrupt), IVR key-press handling, hold detection.
- **Goal:** it sounds like a person and handles a phone tree.

### Phase 3 — Product
- Accounts + auth, a real datastore, a proper task UI, live call transcript view.
- "Pull me in" — conference the user in when a human/verification is needed.
- Task templates (cancel / negotiate / dispute) with the details each needs.
- **Goal:** someone other than you can use it safely.

### Phase 4 — Trust & scale
- Recording + consent flows per jurisdiction, guardrails, abuse prevention.
- Retry logic, callback handling, queueing, observability.
- **Goal:** reliable enough to charge for.

## Rough monthly cost to run (order of magnitude)
Assume a call is ~5 minutes with ~15 conversational turns.

| Item | Unit price (approx) | Per 5-min call |
|------|--------------------|----------------|
| Twilio outbound (US) | ~$0.013 / min | ~$0.07 |
| Twilio phone number | ~$1–2 / mo | fixed |
| Claude (Sonnet class) | a few $ per million tokens | a few cents |
| Deepgram STT (Path B) | ~$0.004–0.01 / min | ~$0.02–0.05 |
| ElevenLabs TTS (Path B) | usage/tiered | ~$0.05–0.15 |
| **Total per call** | | **~$0.15–0.40** |

So a handful of calls costs pennies to a couple dollars; the fixed costs are tiny.
The real cost of scaling is reliability engineering, not per-call spend. Prices
change — treat these as ballpark and check each vendor's current pricing.

## Legal / ethical checklist (do not skip)
- **Disclose it's an AI** when asked, and ideally up front.
- **Recording consent:** some US states require all-party consent; many countries too.
- **TCPA / robocall rules:** don't auto-dial people without consent; this is for
  calling *businesses on your own behalf*, not outbound marketing.
- **No impersonation:** KindredAgent assists; it does not pretend to be the account holder.
- **Authorization:** for account changes, plan a verified-handoff step.

When in doubt, talk to a lawyer before taking on real users.
