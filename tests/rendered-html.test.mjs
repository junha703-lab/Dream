import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);

test("keeps the student experience and 2022 competencies in the product", async () => {
  const page = await readFile(new URL("app/page.tsx", root), "utf8");

  for (const competency of [
    "자기관리 역량",
    "지식정보처리 역량",
    "창의적 사고 역량",
    "심미적 감성 역량",
    "협력적 소통 역량",
    "공동체 역량",
  ]) {
    assert.match(page, new RegExp(competency));
  }

  assert.match(page, /일자리 탐험/);
  assert.match(page, /나의 경제/);
  assert.match(page, /은행원 전용/);
  assert.match(page, /내가 보낸 신청은 다른 은행원이나 선생님이 처리합니다/);
  assert.match(page, /마이룸/);
  assert.match(page, /결과물 사진 또는 링크/);
  assert.match(page, /캐릭터 꾸미기/);
  assert.match(page, /학생 기본직업 배정/);
  assert.match(page, /공동체 목표·자리 설정/);
  assert.match(page, /새 공고 템플릿 만들기/);
  assert.doesNotMatch(page, /학생 순위|역량 구매|직업 Lv\./);
});

test("keeps the remaining classroom workflows server-controlled", async () => {
  const [migration, studentApi, teacherApi] = await Promise.all([
    readFile(new URL("supabase/migrations/20260810060041_complete_remaining_classroom_system.sql", root), "utf8"),
    readFile(new URL("app/api/student/route.ts", root), "utf8"),
    readFile(new URL("app/api/teacher/route.ts", root), "utf8"),
  ]);

  for (const fn of [
    "fo_student_update_avatar",
    "fo_teacher_update_salary",
    "fo_teacher_update_seat",
    "fo_teacher_upsert_goal",
    "fo_teacher_create_template",
    "fo_teacher_resolve_exception",
    "refresh_class_exceptions",
    "open_followup_postings",
  ]) assert.match(migration, new RegExp(fn));

  assert.match(studentApi, /update-avatar/);
  assert.match(teacherApi, /create-template/);
  assert.match(teacherApi, /resolve-exception/);
  assert.match(migration, /enable row level security/);
  assert.match(migration, /on conflict\(source_template_id,target_template_id\)/);
});

test("keeps Supabase sessions server-side and deployment targets explicit", async () => {
  const [supabase, packageJson, hosting] = await Promise.all([
    readFile(new URL("lib/supabase-rest.ts", root), "utf8"),
    readFile(new URL("package.json", root), "utf8"),
    readFile(new URL(".openai/hosting.json", root), "utf8"),
  ]);

  assert.match(supabase, /HttpOnly/);
  assert.match(supabase, /SameSite=Strict/);
  assert.match(supabase, /SUPABASE_PUBLISHABLE_KEY/);
  assert.doesNotMatch(supabase, /service_role|sb_secret_/);

  const pkg = JSON.parse(packageJson);
  assert.equal(pkg.scripts.build, "next build");
  assert.equal(pkg.scripts["sites:build"], "vinext build");
  assert.equal(pkg.dependencies.next, "16.2.6");

  const hostingConfig = JSON.parse(hosting);
  assert.ok(hostingConfig.project_id);
});

test("records basic-job work with evidence instead of a self-reported completion click", async () => {
  const [page, studentApi, migration] = await Promise.all([
    readFile(new URL("app/page.tsx", root), "utf8"),
    readFile(new URL("app/api/student/route.ts", root), "utf8"),
    readFile(new URL("supabase/migrations/20260810094605_add_basic_job_evidence_workflow.sql", root), "utf8"),
  ]);

  assert.doesNotMatch(page, /기본업무 완료 기록/);
  for (const label of ["자동 기록", "사진", "결과물", "친구 확인", "체크 기록"]) {
    assert.match(page, new RegExp(label));
  }
  assert.match(page, /친구에게 확인 요청/);
  assert.match(studentApi, /fo_student_submit_basic_task/);
  assert.match(studentApi, /fo_student_review_basic_task/);
  assert.match(migration, /basic_job_submissions_no_direct_access/);
  assert.match(migration, /bank_review:/);
  assert.match(migration, /credit_basic_job_submission/);
});

test("makes an active teacher week and expired sessions explicit", async () => {
  const [page, teacherApi] = await Promise.all([
    readFile(new URL("app/page.tsx", root), "utf8"),
    readFile(new URL("app/api/teacher/route.ts", root), "utf8"),
  ]);

  assert.match(page, /week-running-banner/);
  assert.match(page, /주차는 이미 시작됐어요/);
  assert.match(page, /다음 주는 이번 주 정산 후 시작할 수 있어요/);
  assert.match(page, /교사 로그인이 만료됐어요/);
  assert.match(teacherApi, /SESSION_EXPIRED/);
  assert.match(teacherApi, /clearSessionCookie\(request, TEACHER_SESSION_COOKIE\)/);
});
