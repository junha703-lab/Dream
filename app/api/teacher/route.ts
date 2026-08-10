import { callSupabaseRpc, clearSessionCookie, readCookie, sessionCookie, TEACHER_SESSION_COOKIE } from "../../../lib/supabase-rest";

type RpcResult = { ok: boolean; code?: string; message?: string; session_token?: string; teacher?: Record<string, unknown> };

function json(body: unknown, status = 200, cookie?: string) {
  const headers = new Headers({ "Content-Type": "application/json", "Cache-Control": "no-store, private" });
  if (cookie) headers.set("Set-Cookie", cookie);
  return new Response(JSON.stringify(body), { status, headers });
}

export async function GET(request: Request) {
  const token = readCookie(request, TEACHER_SESSION_COOKIE);
  if (!token) return json({ ok: false, code: "NO_SESSION" }, 401);
  try {
    const result = await callSupabaseRpc<RpcResult>("fo_teacher_session", { p_session_token: token });
    if (!result.ok) return json(result, 401, clearSessionCookie(request, TEACHER_SESSION_COOKIE));
    return json(result);
  } catch {
    return json({ ok: false, message: "교사 정보를 불러오지 못했습니다." }, 503);
  }
}

export async function POST(request: Request) {
  let body: Record<string, unknown>;
  try { body = await request.json(); } catch { return json({ ok: false, message: "요청 형식을 확인해 주세요." }, 400); }
  const action = String(body.action ?? "");
  try {
    if (action === "login") {
      const result = await callSupabaseRpc<RpcResult>("fo_teacher_login", {
        p_class_code: String(body.classCode ?? "").trim(), p_display_name: String(body.displayName ?? "").trim(), p_pin: String(body.pin ?? ""),
      });
      if (!result.ok || !result.session_token) return json(result, result.code === "LOCKED" ? 429 : 401);
      const { session_token, ...safeResult } = result;
      return json(safeResult, 200, sessionCookie(session_token, request, TEACHER_SESSION_COOKIE));
    }
    const token = readCookie(request, TEACHER_SESSION_COOKIE);
    if (!token) return json({ ok: false, code: "NO_SESSION", message: "다시 로그인해 주세요." }, 401);
    const calls: Record<string, [string, Record<string, unknown>]> = {
      "start-week": ["fo_teacher_start_week", {}],
      "settle-week": ["fo_teacher_settle_week", {}],
      "review-bank": ["fo_teacher_review_bank", { p_request_id: String(body.requestId ?? ""), p_decision: String(body.decision ?? "") }],
    };
    if (action === "logout") {
      await callSupabaseRpc<RpcResult>("fo_teacher_logout", { p_session_token: token });
      return json({ ok: true }, 200, clearSessionCookie(request, TEACHER_SESSION_COOKIE));
    }
    const call = calls[action];
    if (!call) return json({ ok: false, message: "지원하지 않는 요청입니다." }, 400);
    const result = await callSupabaseRpc<RpcResult>(call[0], { p_session_token: token, ...call[1] });
    return json(result, result.ok ? 200 : 400);
  } catch {
    return json({ ok: false, message: "잠시 후 다시 시도해 주세요." }, 503);
  }
}
