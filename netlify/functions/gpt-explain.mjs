const cors = {
  "Access-Control-Allow-Origin": "https://makechess.com",
  "Access-Control-Allow-Headers": "Content-Type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
};

export async function handler(event) {
  if (event.httpMethod === "OPTIONS") {
    return { statusCode: 204, headers: cors, body: "" };
  }
  if (event.httpMethod !== "POST") {
    return { statusCode: 405, headers: cors, body: JSON.stringify({ error: "Method not allowed" }) };
  }

  try {
    const { fen, pv = [], ask = "Кратко объясни позицию и планы." } = JSON.parse(event.body || "{}");
    const key = process.env.OPENAI_API_KEY;
    if (!key) {
      return { statusCode: 500, headers: cors, body: JSON.stringify({ error: "Missing OPENAI_API_KEY" }) };
    }

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        temperature: 0.2,
        messages: [
          { role: "system", content: "Ты — тренер по шахматам. Отвечай кратко и по делу на русском языке." },
          { role: "user", content: `FEN: ${fen}\nХоды: ${Array.isArray(pv) ? pv.join(" ") : "—"}\n\n${ask}` },
        ],
      }),
    });

    const data = await response.json();
    if (!response.ok) {
      return {
        statusCode: response.status,
        headers: cors,
        body: JSON.stringify({ error: data?.error?.message || "OpenAI error" }),
      };
    }

    return {
      statusCode: 200,
      headers: cors,
      body: JSON.stringify({ text: data?.choices?.[0]?.message?.content?.trim() || "" }),
    };
  } catch (error) {
    return { statusCode: 500, headers: cors, body: JSON.stringify({ error: String(error) }) };
  }
}
