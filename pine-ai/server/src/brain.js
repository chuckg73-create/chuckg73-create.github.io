// The "brain": wraps Claude and keeps the running transcript of a call.
//
// Each active call gets a Conversation. When the rep says something (from
// speech-to-text), we call `respond()` which asks Claude for the next spoken
// turn and detects the [END_CALL] signal.

import Anthropic from "@anthropic-ai/sdk";
import { buildCallSystemPrompt, SUMMARY_INSTRUCTION } from "./prompts.js";

const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
const MODEL = process.env.KINDREDAGENT_MODEL || "claude-sonnet-5";

export class Conversation {
  constructor({ task, context }) {
    this.system = buildCallSystemPrompt({ task, context });
    this.turns = []; // {role: "user"|"assistant", content: string}
    this.ended = false;
  }

  // The rep (or IVR) said something. Get KindredAgent's next spoken line.
  // Returns { text, end } where `end` means KindredAgent wants to hang up.
  async respond(repSaid) {
    if (repSaid && repSaid.trim()) {
      this.turns.push({ role: "user", content: repSaid.trim() });
    }
    const msg = await client.messages.create({
      model: MODEL,
      max_tokens: 300,
      system: this.system,
      messages: this.turns,
    });
    let text = msg.content
      .filter((b) => b.type === "text")
      .map((b) => b.text)
      .join(" ")
      .trim();

    let end = false;
    if (text.includes("[END_CALL]")) {
      end = true;
      text = text.replace(/\[END_CALL\]/g, "").trim();
    }
    this.turns.push({ role: "assistant", content: text });
    this.ended = end;
    return { text, end };
  }

  // KindredAgent's opening line, before the rep says anything.
  async opening() {
    return this.respond("[The call just connected. The other party said nothing yet.]");
  }

  async summarize() {
    const msg = await client.messages.create({
      model: MODEL,
      max_tokens: 400,
      system: this.system,
      messages: [...this.turns, { role: "user", content: SUMMARY_INSTRUCTION }],
    });
    return msg.content
      .filter((b) => b.type === "text")
      .map((b) => b.text)
      .join(" ")
      .trim();
  }
}
