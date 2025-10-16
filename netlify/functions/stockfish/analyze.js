// /.netlify/functions/stockfish/analyze
import fetch from "node-fetch";

export const handler = async (event) => {
  try {
    const body = JSON.parse(event.body || "{}");
    const fen = body.fen || "";
    const depth = body.depth || 20;
    const multiPv = body.multiPv || 4;
    const maxThinkingTime = body.maxThinkingTime || 2500;

    const res = await fetch("https://chess-api.com/v1", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        fen,
        depth,
        variants: multiPv,
        maxThinkingTime,
      }),
    });

    const data = await res.json();

    const enriched = {
      ...data,
      analyzedBy: "Stockfish 16",
      source: "Netlify Function",
    };

    return {
      statusCode: 200,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(enriched, null, 2),
    };
  } catch (err) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: String(err) }),
    };
  }
};

