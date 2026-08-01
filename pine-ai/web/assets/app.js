/* KindredAgent demo — the "brain" running client-side.
 *
 * This calls the Anthropic API directly from the browser using a key the user
 * provides. That is fine for a local/personal demo, but for anything real you
 * MUST proxy requests through a backend so your key is never exposed. See
 * ../server for a backend that does this (and also places real calls).
 */

const LS_KEY = "kindredagent.apiKey";
const LS_MODEL = "kindredagent.model";
const API_URL = "https://api.anthropic.com/v1/messages";

const SYSTEM_PROMPT = `You are KindredAgent, an AI assistant that handles phone calls on a user's behalf
(negotiating bills, canceling subscriptions, disputing charges, booking things, etc.).

The user will describe a task. Respond in THIS structure using markdown-style headings
(#### Heading), and keep it tight and practical:

#### Goal
One sentence restating exactly what a successful call achieves.

#### What I need from you
Only if something essential is missing (account number, name, dates, dollar amounts).
List them as short bullets. If you have enough to proceed, say "Nothing — I have what I need."

#### Call plan
3–6 short bullets: who to call, the leverage/strategy, what to ask for, the fallback ask,
and any pitfalls (retention scripts, transfers, "manager" escalation).

#### Opening script
The exact words to open the call with — natural, polite, first person, ready to speak.

#### If they push back
2–4 likely objections and a crisp one-line response to each.

After that structure, add ONE line:
"Want me to role-play the rep so you can practice? Reply and I'll respond as them."

If the user is clearly continuing a role-play (they're speaking as the rep), then DROP the
structure and simply respond in-character as KindredAgent on the call — short, spoken, one turn at a
time — and stay in character until the task is resolved. Never invent confirmation numbers as
if they're real; if you'd need one, note it in [brackets] as a placeholder.

Be honest about limits. Never counsel deception, impersonating the account holder without
authorization, or anything unlawful. If a task requires the account holder's verified identity,
say so.`;

// ---------- state ----------
let messages = []; // {role, content}
const $ = (id) => document.getElementById(id);

function getKey(){ return localStorage.getItem(LS_KEY) || ""; }
function getModel(){ return localStorage.getItem(LS_MODEL) || "claude-sonnet-5"; }

// ---------- settings modal ----------
function openSettings(){
  $("apiKey").value = getKey();
  $("model").value = getModel();
  $("settings").classList.remove("hidden");
}
function closeSettings(){ $("settings").classList.add("hidden"); }

$("settingsBtn").addEventListener("click", (e)=>{e.preventDefault();openSettings();});
$("openSettings")?.addEventListener("click", openSettings);
$("saveKey").addEventListener("click", ()=>{
  localStorage.setItem(LS_KEY, $("apiKey").value.trim());
  localStorage.setItem(LS_MODEL, $("model").value);
  closeSettings();
  refreshKeyNotice();
});
$("clearKey").addEventListener("click", ()=>{
  localStorage.removeItem(LS_KEY);
  $("apiKey").value = "";
  refreshKeyNotice();
});
$("settings").addEventListener("click",(e)=>{ if(e.target.id==="settings") closeSettings(); });

function refreshKeyNotice(){
  const has = !!getKey();
  $("keyNotice").classList.toggle("hidden", has);
}

// ---------- examples ----------
document.querySelectorAll(".chip").forEach(chip=>{
  chip.addEventListener("click", ()=>{
    $("input").value = chip.dataset.ex;
    $("input").focus();
    autoGrow($("input"));
  });
});

// ---------- composer ----------
const input = $("input");
function autoGrow(el){ el.style.height="auto"; el.style.height=Math.min(el.scrollHeight,200)+"px"; }
input.addEventListener("input", ()=>autoGrow(input));
input.addEventListener("keydown",(e)=>{
  if(e.key==="Enter" && !e.shiftKey){ e.preventDefault(); $("composer").requestSubmit(); }
});

$("composer").addEventListener("submit", async (e)=>{
  e.preventDefault();
  const text = input.value.trim();
  if(!text) return;
  if(!getKey()){ openSettings(); return; }

  addMessage("user", text);
  messages.push({role:"user", content:text});
  input.value=""; autoGrow(input);
  $("examples").classList.add("hidden");

  const bubble = addMessage("assistant", "");
  bubble.querySelector(".body").innerHTML = '<span class="typing"><span></span><span></span><span></span></span>';
  setBusy(true);

  try{
    const reply = await callClaude();
    messages.push({role:"assistant", content:reply});
    bubble.querySelector(".body").innerHTML = render(reply);
  }catch(err){
    bubble.querySelector(".body").innerHTML =
      '<span class="err">⚠ '+escapeHtml(err.message)+'</span>';
  }finally{
    setBusy(false);
    bubble.scrollIntoView({behavior:"smooth", block:"end"});
  }
});

function setBusy(b){ $("send").disabled=b; $("send").textContent = b ? "Thinking…" : "Plan the call"; }

// ---------- Claude call ----------
async function callClaude(){
  const res = await fetch(API_URL, {
    method:"POST",
    headers:{
      "content-type":"application/json",
      "x-api-key":getKey(),
      "anthropic-version":"2023-06-01",
      // Required to call the API directly from a browser. Do this only for a
      // personal/local demo — a leaked key can cost you real money.
      "anthropic-dangerous-direct-browser-access":"true"
    },
    body: JSON.stringify({
      model:getModel(),
      max_tokens:1200,
      system:SYSTEM_PROMPT,
      messages: messages.map(m=>({role:m.role, content:m.content}))
    })
  });
  if(!res.ok){
    let detail="";
    try{ const j=await res.json(); detail = j.error?.message || JSON.stringify(j); }catch(_){ detail = await res.text(); }
    if(res.status===401) throw new Error("Invalid API key. Check it in the API key panel.");
    throw new Error("API error ("+res.status+"): "+detail);
  }
  const data = await res.json();
  return (data.content||[]).filter(b=>b.type==="text").map(b=>b.text).join("\n").trim()
    || "(No response)";
}

// ---------- rendering ----------
function addMessage(role, text){
  const el = document.createElement("div");
  el.className = "msg "+role;
  el.innerHTML = '<span class="role">'+(role==="user"?"You":"🧭 KindredAgent")+'</span><div class="body">'+render(text)+'</div>';
  $("chat").appendChild(el);
  el.scrollIntoView({behavior:"smooth", block:"end"});
  return el;
}
function render(text){
  if(!text) return "";
  let html = escapeHtml(text);
  html = html.replace(/^#### (.*)$/gm, "<h4>$1</h4>");
  html = html.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
  return html;
}
function escapeHtml(s){
  return s.replace(/[&<>]/g, c=>({"&":"&amp;","<":"&lt;",">":"&gt;"}[c]));
}

// ---------- init ----------
refreshKeyNotice();
