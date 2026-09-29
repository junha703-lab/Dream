import { callSupabaseRpc, clearSessionCookie, readCookie, sessionCookie, STUDENT_SESSION_COOKIE } from "../../../lib/supabase-rest";

type RpcResult = {
  ok: boolean;
  code?: string;
  message?: string;
  session_token?: string;
  student?: Record<string, unknown>;
};

function json(body: unknown, status = 200, cookie?: string) {
  const headers = new Headers({ "Content-Type": "application/json", "Cache-Control": "no-store, private" });
  if (cookie) headers.set("Set-Cookie", cookie);
  return new Response(JSON.stringify(body), { status, headers });
}

export async function GET(request: Request) {
  const token = readCookie(request, STUDENT_SESSION_COOKIE);
  if (!token) return json({ ok: false, code: "NO_SESSION" }, 401);
  try {
    const result = await callSupabaseRpc<RpcResult>("fo_student_session", { p_session_token: token });
    if (!result.ok) return json(result, 401, clearSessionCookie(request));
    return json(result);
  } catch {
    return json({ ok: false, message: "학생 정보를 불러오지 못했습니다." }, 503);
  }
}

export async function POST(request: Request) {
  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return json({ ok: false, message: "요청 형식을 확인해 주세요." }, 400);
  }

  const action = String(body.action ?? "");
  try {
    if (action === "login") {
      const result = await callSupabaseRpc<RpcResult>("fo_student_login", {
        p_class_code: String(body.classCode ?? "").trim(),
        p_display_name: String(body.displayName ?? "").trim(),
        p_pin: String(body.pin ?? ""),
      });
      if (!result.ok || !result.session_token) return json(result, result.code === "LOCKED" ? 429 : 401);
      const { session_token, ...safeResult } = result;
      return json(safeResult, 200, sessionCookie(session_token, request));
    }

    const token = readCookie(request, STUDENT_SESSION_COOKIE);
    if (!token) return json({ ok: false, code: "NO_SESSION", message: "다시 로그인해 주세요." }, 401);

    if (action === "change-pin") {
      const result = await callSupabaseRpc<RpcResult>("fo_student_change_pin", { p_session_token: token, p_new_pin: String(body.pin ?? "") });
      return json(result, result.ok ? 200 : 400);
    }
    if (action === "choose-job") {
      const result = await callSupabaseRpc<RpcResult>("fo_student_choose_job", { p_session_token: token, p_job_code: String(body.jobCode ?? "") });
      return json(result, result.ok ? 200 : 400);
    }
    if (action === "complete-task") {
      const result = await callSupabaseRpc<RpcResult>("fo_complete_basic_task", { p_session_token: token });
      return json(result, result.ok ? 200 : 400);
    }
    if (action === "submit-basic-task") {
      const result = await callSupabaseRpc<RpcResult>("fo_student_submit_basic_task", {
        p_session_token: token,
        p_task_id: String(body.taskId ?? ""),
        p_summary: String(body.summary ?? ""),
        p_evidence_url: String(body.evidenceUrl ?? ""),
        p_verifier_student_id: body.verifierStudentId ? String(body.verifierStudentId) : null,
      });
      return json(result, result.ok ? 200 : 400);
    }
    if (action === "review-basic-task") {
      const result = await callSupabaseRpc<RpcResult>("fo_student_review_basic_task", {
        p_session_token: token,
        p_submission_id: String(body.submissionId ?? ""),
        p_decision: String(body.decision ?? ""),
      });
      return json(result, result.ok ? 200 : 400);
    }
    if (action === "save") {
      const result = await callSupabaseRpc<RpcResult>("fo_student_save", { p_session_token: token, p_amount: Number(body.amount ?? 0) });
      return json(result, result.ok ? 200 : 400);
    }
    if (action === "apply-job") {
      const result = await callSupabaseRpc<RpcResult>("fo_student_apply", { p_session_token: token, p_posting_id: String(body.postingId ?? "") });
      return json(result, result.ok ? 200 : 400);
    }
    if (action === "complete-job") {
      const result = await callSupabaseRpc<RpcResult>("fo_student_complete_job", {
        p_session_token: token,
        p_application_id: String(body.applicationId ?? ""),
        p_summary: String(body.summary ?? ""),
        p_result_url: String(body.resultUrl ?? ""),
        p_fun: Number(body.fun ?? 0),
        p_difficulty: Number(body.difficulty ?? 0),
      });
      return json(result, result.ok ? 200 : 400);
    }
    if (action === "resubmit-job-evidence") {
      const result = await callSupabaseRpc<RpcResult>("fo_student_resubmit_job_evidence", {
        p_session_token: token,
        p_application_id: String(body.applicationId ?? ""),
        p_summary: String(body.summary ?? ""),
        p_result_url: String(body.resultUrl ?? ""),
        p_fun: Number(body.fun ?? 0),
        p_difficulty: Number(body.difficulty ?? 0),
      });
      return json(result, result.ok ? 200 : 400);
    }
    if (action === "bank-request") {
      const result = await callSupabaseRpc<RpcResult>("fo_student_bank_request", { p_session_token: token, p_type: String(body.type ?? ""), p_amount: Number(body.amount ?? 0) });
      return json(result, result.ok ? 200 : 400);
    }
    if (action === "review-bank") {
      const result = await callSupabaseRpc<RpcResult>("fo_student_review_bank", { p_session_token: token, p_request_id: String(body.requestId ?? ""), p_decision: String(body.decision ?? "") });
      return json(result, result.ok ? 200 : 400);
    }
    if (action === "donate") {
      const result = await callSupabaseRpc<RpcResult>("fo_student_donate", { p_session_token: token, p_goal_id: String(body.goalId ?? ""), p_amount: Number(body.amount ?? 0) });
      return json(result, result.ok ? 200 : 400);
    }
    if (action === "equip-room") {
      const result = await callSupabaseRpc<RpcResult>("fo_student_equip_room", { p_session_token: token, p_item_key: String(body.itemKey ?? "") });
      return json(result, result.ok ? 200 : 400);
    }
    if (action === "request-seat") {
      const result = await callSupabaseRpc<RpcResult>("fo_student_request_seat", { p_session_token: token, p_seat_id: String(body.seatId ?? "") });
      return json(result, result.ok ? 200 : 400);
    }
    if (action === "update-avatar") {
      const result = await callSupabaseRpc<RpcResult>("fo_student_update_avatar", {
        p_session_token: token,
        p_hair: String(body.hair ?? ""),
        p_background: String(body.background ?? ""),
        p_badge_key: body.badgeKey ? String(body.badgeKey) : null,
      });
      return json(result, result.ok ? 200 : 400);
    }
    if (action === "logout") {
      await callSupabaseRpc<RpcResult>("fo_student_logout", { p_session_token: token });
      return json({ ok: true }, 200, clearSessionCookie(request));
    }
    return json({ ok: false, message: "지원하지 않는 요청입니다." }, 400);
  } catch {
    return json({ ok: false, message: "잠시 후 다시 시도해 주세요." }, 503);
  }
}
