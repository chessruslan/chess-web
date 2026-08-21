// deno-lint-ignore-file no-explicit-any
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
};
const jsonHeaders = { ...cors, "content-type": "application/json; charset=utf-8" };
const LICHESS = "https://lichess.org";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function base64Url(bytes: Uint8Array) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
}

function randomToken(size = 32) {
  return base64Url(crypto.getRandomValues(new Uint8Array(size)));
}

async function sha256(value: string) {
  return base64Url(new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value))));
}

function admin() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
}

function safeReturnUrl(raw: unknown) {
  try {
    const value = new URL(String(raw ?? "https://makechess.com/"));
    const allowed = value.hostname === "makechess.com" ||
      value.hostname.endsWith(".makechess.com") ||
      value.hostname === "localhost" || value.hostname === "127.0.0.1";
    return allowed ? value.toString() : "https://makechess.com/";
  } catch (_) {
    return "https://makechess.com/";
  }
}

async function currentUser(req: Request) {
  const authorization = req.headers.get("authorization") ?? "";
  if (!authorization.toLowerCase().startsWith("bearer ")) return null;
  const client = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authorization } }, auth: { persistSession: false } },
  );
  const { data } = await client.auth.getUser();
  return data.user;
}

async function connection(userId: string) {
  const { data } = await admin().from("lichess_connections")
    .select("lichess_user_id,lichess_username,access_token,scopes")
    .eq("user_id", userId).maybeSingle();
  return data;
}

async function lichessRequest(token: string, path: string, init: RequestInit = {}) {
  return await fetch(`${LICHESS}${path}`, {
    ...init,
    headers: { Authorization: `Bearer ${token}`, ...(init.headers ?? {}) },
  });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  const url = new URL(req.url);

  try {
    if (req.method === "GET" && url.searchParams.get("callback") === "1") {
      const code = url.searchParams.get("code") ?? "";
      const state = url.searchParams.get("state") ?? "";
      const db = admin();
      const { data: pending } = await db.from("lichess_oauth_states").select("*").eq("state", state).maybeSingle();
      if (!code || !pending) return new Response("Invalid or expired OAuth state", { status: 400 });
      await db.from("lichess_oauth_states").delete().eq("state", state);

      const callbackUrl = `${url.origin}${url.pathname}?callback=1`;
      const tokenResponse = await fetch(`${LICHESS}/api/token`, {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          grant_type: "authorization_code",
          code,
          code_verifier: pending.code_verifier,
          redirect_uri: callbackUrl,
          client_id: Deno.env.get("LICHESS_CLIENT_ID") ?? "makechess.com",
        }),
      });
      if (!tokenResponse.ok) return new Response("Lichess did not confirm authorization", { status: 502 });
      const tokenData = await tokenResponse.json();
      const accountResponse = await lichessRequest(tokenData.access_token, "/api/account");
      if (!accountResponse.ok) return new Response("Cannot read Lichess account", { status: 502 });
      const account = await accountResponse.json();
      await db.from("lichess_connections").upsert({
        user_id: pending.user_id,
        lichess_user_id: account.id,
        lichess_username: account.username,
        access_token: tokenData.access_token,
        scopes: tokenData.scope ?? "board:play",
        updated_at: new Date().toISOString(),
      });
      const returnUrl = new URL(pending.return_url);
      returnUrl.searchParams.set("lichess", "connected");
      return Response.redirect(returnUrl.toString(), 302);
    }

    const user = await currentUser(req);
    if (!user) return json({ error: "authentication_required" }, 401);
    const body = req.method === "POST" ? await req.json().catch(() => ({})) : {};
    const action = body.action ?? url.searchParams.get("action") ?? "status";

    if (action === "start") {
      const verifier = randomToken(48);
      const state = randomToken(32);
      const returnUrl = safeReturnUrl(body.returnUrl);
      const callbackUrl = `${url.origin}${url.pathname}?callback=1`;
      await admin().from("lichess_oauth_states").delete().lt("created_at", new Date(Date.now() - 15 * 60_000).toISOString());
      const { error } = await admin().from("lichess_oauth_states").insert({
        state, user_id: user.id, code_verifier: verifier, return_url: returnUrl,
      });
      if (error) return json({ error: "oauth_state_failed" }, 500);
      const auth = new URL(`${LICHESS}/oauth`);
      auth.search = new URLSearchParams({
        response_type: "code",
        client_id: Deno.env.get("LICHESS_CLIENT_ID") ?? "makechess.com",
        redirect_uri: callbackUrl,
        code_challenge_method: "S256",
        code_challenge: await sha256(verifier),
        scope: "board:play",
        state,
      }).toString();
      return json({ authorizationUrl: auth.toString() });
    }

    const linked = await connection(user.id);
    if (action === "status") return json({ connected: !!linked, username: linked?.lichess_username ?? null });
    if (action === "disconnect") {
      if (linked?.access_token) await lichessRequest(linked.access_token, "/api/token", { method: "DELETE" });
      await admin().from("lichess_connections").delete().eq("user_id", user.id);
      return json({ ok: true });
    }
    if (!linked) return json({ error: "lichess_not_connected" }, 409);

    if (action === "events") {
      const response = await lichessRequest(linked.access_token, "/api/stream/event", {
        headers: { accept: "application/x-ndjson" },
      });
      return new Response(response.body, {
        status: response.status,
        headers: { ...cors, "content-type": "application/x-ndjson", "cache-control": "no-store" },
      });
    }

    if (action === "gameStream") {
      const requestedId = encodeURIComponent(String(url.searchParams.get("gameId") ?? body.gameId ?? ""));
      if (!requestedId) return json({ error: "game_id_required" }, 400);
      const response = await lichessRequest(linked.access_token, `/api/board/game/stream/${requestedId}`, {
        headers: { accept: "application/x-ndjson" },
      });
      return new Response(response.body, {
        status: response.status,
        headers: { ...cors, "content-type": "application/x-ndjson", "cache-control": "no-store" },
      });
    }

    if (action === "seek") {
      const form = new URLSearchParams({
        rated: body.rated === true ? "true" : "false",
        time: String(body.minutes ?? 10),
        increment: String(body.increment ?? 0),
        variant: "standard",
        color: "random",
      });
      const response = await lichessRequest(linked.access_token, "/api/board/seek", {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded", accept: "application/x-ndjson" },
        body: form,
      });
      return new Response(response.body, { status: response.status, headers: { ...cors, "content-type": response.headers.get("content-type") ?? "application/x-ndjson", "cache-control": "no-store" } });
    }

    const gameId = encodeURIComponent(String(body.gameId ?? ""));
    if (!gameId) return json({ error: "game_id_required" }, 400);
    const routes: Record<string, [string, string]> = {
      move: ["POST", `/api/board/game/${gameId}/move/${encodeURIComponent(String(body.move ?? ""))}`],
      resign: ["POST", `/api/board/game/${gameId}/resign`],
      draw: ["POST", `/api/board/game/${gameId}/draw/${body.accept === false ? "no" : "yes"}`],
      abort: ["POST", `/api/board/game/${gameId}/abort`],
    };
    const route = routes[action];
    if (!route) return json({ error: "unknown_action" }, 400);
    const response = await lichessRequest(linked.access_token, route[1], { method: route[0] });
    return new Response(await response.text(), { status: response.status, headers: jsonHeaders });
  } catch (error) {
    return json({ error: "lichess_integration_error", detail: String(error) }, 500);
  }
});
