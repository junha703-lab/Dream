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
  assert.match(page, /마이룸/);
  assert.doesNotMatch(page, /학생 순위|역량 구매|직업 Lv\./);
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
