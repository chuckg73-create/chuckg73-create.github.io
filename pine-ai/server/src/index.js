// Cedar backend — places a real phone call and lets Claude drive the conversation.
//
// Flow (simplest, Twilio-native voice):
//   1. POST /calls        -> you tell Cedar the task + number to call. We start a Twilio call.
//   2. Twilio hits /voice  -> we return TwiML: Cedar speaks its opening line, then <Gather>
//                             listens for the rep's reply via Twilio speech-to-text.
//   3. Twilio hits /gather -> we send what the rep said to Claude, speak the reply, gather again.
//   4. On [END_CALL]       -> we <Hangup> and generate a summary.
//
// This uses Twilio's built-in <Say>/<Gather> for STT/TTS: zero extra vendors, good enough to
// demo. For natural, low-latency voice, swap in a Media Streams websocket with Deepgram (STT)
// + ElevenLabs (TTS) — see docs/ARCHITECTURE.md. That path is stubbed in stream.js.

import "dotenv/config";
import express from "express";
import twilio from "twilio";
import { Conversation } from "./brain.js";

const app = express();
app.use(express.urlencoded({ extended: false })); // Twilio posts form-encoded
app.use(express.json());

const {
  TWILIO_ACCOUNT_SID,
  TWILIO_AUTH_TOKEN,
  TWILIO_FROM_NUMBER,
  PUBLIC_BASE_URL,
  PORT = 3000,
} = process.env;

const twilioClient = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);
const VoiceResponse = twilio.twiml.VoiceResponse;

// In-memory call registry. For production, use a real store (Redis/DB).
const calls = new Map(); // callSid -> { convo, task, summary }

// --- 1. Start a call ---------------------------------------------------------
app.post("/calls", async (req, res) => {
  const { to, task, context } = req.body;
  if (!to || !task) {
    return res.status(400).json({ error: "Provide `to` (phone number) and `task`." });
  }
  const convo = new Conversation({ task, context });

  try {
    const call = await twilioClient.calls.create({
      to,
      from: TWILIO_FROM_NUMBER,
      url: `${PUBLIC_BASE_URL}/voice`, // Twilio fetches TwiML from here when the callee answers
      // Optional: get status callbacks (answered, completed, etc.)
      statusCallback: `${PUBLIC_BASE_URL}/status`,
      statusCallbackEvent: ["initiated", "answered", "completed"],
    });
    calls.set(call.sid, { convo, task, summary: null });
    res.json({ callSid: call.sid, status: "dialing" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// --- 2. Call answered: Cedar speaks first ------------------------------------
app.post("/voice", async (req, res) => {
  const callSid = req.body.CallSid;
  const entry = calls.get(callSid);
  const twiml = new VoiceResponse();

  if (!entry) {
    twiml.say("Sorry, this call could not be set up.");
    twiml.hangup();
    return res.type("text/xml").send(twiml.toString());
  }

  try {
    const { text, end } = await entry.convo.opening();
    speakAndGather(twiml, text, end);
  } catch (err) {
    twiml.say("I'm having a technical problem. I'll call back later. Goodbye.");
    twiml.hangup();
  }
  res.type("text/xml").send(twiml.toString());
});

// --- 3. Rep replied: send to Claude, speak the answer ------------------------
app.post("/gather", async (req, res) => {
  const callSid = req.body.CallSid;
  const repSaid = req.body.SpeechResult || "";
  const entry = calls.get(callSid);
  const twiml = new VoiceResponse();

  if (!entry) {
    twiml.hangup();
    return res.type("text/xml").send(twiml.toString());
  }

  try {
    const { text, end } = await entry.convo.respond(repSaid);
    speakAndGather(twiml, text, end);
    if (end) finalizeCall(callSid); // generate summary in the background
  } catch (err) {
    twiml.say("Sorry, I lost my train of thought. Let me follow up another time. Goodbye.");
    twiml.hangup();
  }
  res.type("text/xml").send(twiml.toString());
});

// --- Status + summary --------------------------------------------------------
app.post("/status", (req, res) => {
  const { CallSid, CallStatus } = req.body;
  if (CallStatus === "completed") finalizeCall(CallSid);
  res.sendStatus(200);
});

app.get("/calls/:sid", (req, res) => {
  const entry = calls.get(req.params.sid);
  if (!entry) return res.status(404).json({ error: "unknown call" });
  res.json({ task: entry.task, summary: entry.summary, done: entry.convo.ended });
});

async function finalizeCall(callSid) {
  const entry = calls.get(callSid);
  if (!entry || entry.summary) return;
  try {
    entry.summary = await entry.convo.summarize();
    console.log(`\n=== Summary for ${callSid} ===\n${entry.summary}\n`);
  } catch (err) {
    console.error("summary failed:", err.message);
  }
}

// --- TwiML helper: say a line, then listen for the reply ----------------------
function speakAndGather(twiml, text, end) {
  if (text) twiml.say({ voice: "Polly.Joanna" }, text);
  if (end) {
    twiml.hangup();
    return;
  }
  const gather = twiml.gather({
    input: "speech",
    action: "/gather",
    method: "POST",
    speechTimeout: "auto",
    speechModel: "phone_call",
  });
  // If the rep says nothing, prompt once, then Twilio will re-hit /voice logic via redirect.
  twiml.redirect("/gather"); // fallback if no speech captured
}

app.get("/", (_req, res) => res.send("Cedar server is running. POST /calls to start a call."));

app.listen(PORT, () => {
  console.log(`🌲 Cedar server on :${PORT}`);
  if (!PUBLIC_BASE_URL) console.warn("⚠  Set PUBLIC_BASE_URL — Twilio must reach this server.");
  if (!TWILIO_ACCOUNT_SID) console.warn("⚠  Missing Twilio credentials in .env");
});
