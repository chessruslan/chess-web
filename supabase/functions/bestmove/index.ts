// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "*",
  "Access-Control-Allow-Methods": "POST,OPTIONS",
};

const ENGINE_URL = "https://chess-api.com/v1/";

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });

  try {
    const bodyText = await req.text();

    const upstream = await fetch(ENGINE_URL, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: bodyText,
      // @ts-ignore
      signal: AbortSignal.timeout(8000),
    });

    const text = await upstream.text();
    return new Response(text, {
      status: upstream.status,
      headers: {
        ...cors,
        "content-type": upstream.headers.get("content-type") ?? "application/json",
      },
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ error: "engine_unreachable", detail: String(e) }),
      { status: 504, headers: { ...cors, "content-type": "application/json" } },
    );
  }
});

