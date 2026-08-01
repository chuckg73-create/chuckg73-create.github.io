// OPTIONAL upgrade path: natural, low-latency voice via Twilio Media Streams.
//
// The /voice + /gather flow in index.js works and needs no extra vendors, but it
// sounds robotic and has a beat of latency between turns. For a Pine-AI-quality
// voice, stream raw audio both ways over a websocket:
//
//   Twilio  --(caller audio, 8kHz μ-law)-->  your server  --> Deepgram (STT) --> text
//   text --> Claude (brain) --> reply text --> ElevenLabs (TTS) --> audio --> Twilio
//
// This file is a SKELETON showing where each piece plugs in. It is intentionally
// not wired into index.js yet — flip to it once the basic flow works end to end.

import { WebSocketServer } from "ws";
import { Conversation } from "./brain.js";

// Attach to an existing HTTP server: attachMediaStream(server)
export function attachMediaStream(server) {
  const wss = new WebSocketServer({ server, path: "/media" });

  wss.on("connection", (ws) => {
    let convo = null;
    let streamSid = null;

    ws.on("message", async (raw) => {
      const msg = JSON.parse(raw.toString());

      switch (msg.event) {
        case "start":
          streamSid = msg.start.streamSid;
          // Task/context can be passed via customParameters on the <Stream> TwiML.
          convo = new Conversation({
            task: msg.start.customParameters?.task || "Assist the caller.",
            context: msg.start.customParameters?.context || "",
          });
          // TODO: open a Deepgram live-transcription socket here.
          // TODO: speak Cedar's opening via ElevenLabs -> send audio frames to Twilio.
          break;

        case "media":
          // msg.media.payload is base64 μ-law audio from the caller.
          // TODO: forward these bytes to Deepgram. On a final transcript:
          //   const { text, end } = await convo.respond(transcript);
          //   const audio = await synthesize(text);   // ElevenLabs -> μ-law 8kHz
          //   sendAudioToTwilio(ws, streamSid, audio);
          //   if (end) ws.close();
          break;

        case "stop":
          if (convo) {
            const summary = await convo.summarize();
            console.log("Call summary:", summary);
          }
          break;
      }
    });
  });
}

// Frame audio back to Twilio over the same websocket.
export function sendAudioToTwilio(ws, streamSid, base64Mulaw) {
  ws.send(JSON.stringify({ event: "media", streamSid, media: { payload: base64Mulaw } }));
}

// --- vendor stubs (implement with your chosen providers) ---
// export async function synthesize(text) { /* ElevenLabs TTS -> 8kHz μ-law base64 */ }
// export function openDeepgram(onTranscript) { /* Deepgram live STT websocket */ }
