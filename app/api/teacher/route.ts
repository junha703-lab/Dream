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
      "create-student": ["fo_teacher_create_student", { p_name: String(body.name ?? ""), p_number: Number(body.number ?? 0), p_job_code: String(body.jobCode ?? ""), p_temp_pin: String(body.tempPin ?? "") }],
      "assign-job": ["fo_teacher_assign_job", { p_student_id: String(body.studentId ?? ""), p_job_code: String(body.jobCode ?? ""), p_salary: Number(body.salary ?? 0) }],
      "open-template": ["fo_teacher_open_template", { p_template_id: String(body.templateId ?? "") }],
      "review-seat": ["fo_teacher_review_seat", { p_request_id: String(body.requestId ?? ""), p_decision: String(body.decision ?? "") }],
      "update-class": ["fo_teacher_update_class", { p_name: String(body.name ?? ""), p_grade: Number(body.grade ?? 0), p_section: Number(body.section ?? 0) }],
      "update-salary": ["fo_teacher_update_salary", { p_job_code: String(body.jobCode ?? ""), p_salary: Number(body.salary ?? 0) }],
      "update-seat": ["fo_teacher_update_seat", { p_seat_id: String(body.seatId ?? ""), p_name: String(body.name ?? ""), p_type: String(body.type ?? ""), p_rent: Number(body.rent ?? 0), p_move_cost: Number(body.moveCost ?? 0), p_active: Boolean(body.active) }],
      "update-goal": ["fo_teacher_upsert_goal", { p_title: String(body.title ?? ""), p_description: String(body.description ?? ""), p_target: Number(body.target ?? 0), p_min_donations: Number(body.minDonations ?? 0) }],
      "create-template": ["fo_teacher_create_template", { p_title: String(body.title ?? ""), p_description: String(body.description ?? ""), p_world_key: String(body.worldKey ?? ""), p_related_job_codes: Array.isArray(body.relatedJobCodes) ? body.relatedJobCodes.map(String) : [], p_capacity: Number(body.capacity ?? 0), p_reward: Number(body.reward ?? 0), p_duration: Number(body.duration ?? 0), p_competency_rewards: body.competencyRewards ?? {}, p_submission_method: String(body.submissionMethod ?? ""), p_repeatable: Boolean(body.repeatable) }],
      "resolve-exception": ["fo_teacher_resolve_exception", { p_exception_id: String(body.exceptionId ?? "") }],
    };
    if (action === "logout") {
      await callSupabaseRpc<RpcResult>("fo_teacher_logout", { p_session_token: token });
      return json({ ok: true }, 200, clearSessionCookie(request, TEACHER_SESSION_COOKIE));
    }
    const call = calls[action];
    if (!call) return json({ ok: false, message: "지원하지 않는 요청입니다." }, 400);
    const result = await callSupabaseRpc<RpcResult>(call[0], { p_session_token: token, ...call[1] });
    if (!result.ok) {
      if (result.code === "SESSION_EXPIRED") {
        console.warn("[api/teacher] session expired", { action });
        return json({ ...result, message: "로그인이 만료됐어요. 다시 로그인해 주세요." }, 401, clearSessionCookie(request, TEACHER_SESSION_COOKIE));
      }
      return json(result, 400);
    }
    const refreshed = await callSupabaseRpc<RpcResult>("fo_teacher_session", { p_session_token: token });
    return json({ ...result, teacher: refreshed.teacher });
  } catch {
    return json({ ok: false, message: "잠시 후 다시 시도해 주세요." }, 503);
  }
}
