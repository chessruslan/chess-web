// deno deploy on supabase edge
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  // КЛЮЧЕВАЯ строчка — явно указываем UTF-8:
  "Content-Type": "application/json; charset=utf-8",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  try {
    const { fen, pv = [], ask = "Кратко объясни позицию и планы." } =
      await req.json();

    const sys =
      "Ты — тренер по шахматам. Объясняй кратко и по делу, на русском. До 8–10 предложений.";
    const user =
      `FEN: ${fen}\nХоды (SAN): ${Array.isArray(pv) && pv.length ? pv.join(" ") : "—"}\n\n${ask}`;

    const key = Deno.env.get("OPENAI_API_KEY");
    if (!key) {
      return new Response(JSON.stringify({ error: "Missing OPENAI_API_KEY" }), {
        status: 500,
        headers: cors,
      });
    }

    const r = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${key}`,
        "Content-Type": "application/json; charset=utf-8",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        temperature: 0.2,
        messages: [
          { role: "system", content: sys },
          { role: "user", content: user },
        ],
      }),
    });

    const data = await r.json();
    if (!r.ok) {
      const msg = data?.error?.message ?? "OpenAI error";
      return new Response(JSON.stringify({ error: msg }), {
        status: r.status,
        headers: cors,
      });
    }

    const text: string = data?.choices?.[0]?.message?.content?.trim() ?? "";
    // Отдаём JSON строго в UTF-8
    return new Response(JSON.stringify({ text }), { status: 200, headers: cors });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: cors,
    });
  }
});
