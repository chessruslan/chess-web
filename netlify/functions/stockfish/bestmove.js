// /.netlify/functions/stockfish/bestmove
import fetch from "node-fetch";

export const handler = async (event) => {
  try {
    const body = JSON.parse(event.body || "{}");
    const fen = body.fen || "";
    const depth = body.depth || 18;
    const multiPv = body.multiPv || 1;
    const maxThinkingTime = body.maxThinkingTime || 2000;

    // запрос к chess-api (или своему движку)
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

    // добавим “богатые” поля, как раньше
    const enriched = {
      ...data,
      turn: "w",
      color: "w",
      fromNumeric: "42",
      toNumeric: "44",
      continuation: [
        {
          from: "d7",
          to: "d5",
          fromNumeric: "47",
          toNumeric: "45",
        },
      ],
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
