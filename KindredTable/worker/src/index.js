const GEMINI_BASE = "https://generativelanguage.googleapis.com";

export default {
  async fetch(request, env) {
    // Only POST allowed
    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    // Path: /v1beta/models/<model>:generateContent
    const url = new URL(request.url);
    const geminiURL = new URL(GEMINI_BASE + url.pathname);
    geminiURL.searchParams.set("key", env.GEMINI_API_KEY);

    const body = await request.arrayBuffer();

    const geminiResponse = await fetch(geminiURL.toString(), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
    });

    const responseBody = await geminiResponse.arrayBuffer();

    return new Response(responseBody, {
      status: geminiResponse.status,
      headers: {
        "Content-Type": geminiResponse.headers.get("Content-Type") || "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    });
  },
};
