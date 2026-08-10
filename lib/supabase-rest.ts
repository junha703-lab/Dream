const SUPABASE_URL = process.env.SUPABASE_URL ?? "https://okbrapkebgyieyvuxamb.supabase.co";
const SUPABASE_PUBLISHABLE_KEY = process.env.SUPABASE_PUBLISHABLE_KEY ?? "sb_publishable_dqiMOBo-trOR-f44ZDxYDg_fdibKmDo";

export const STUDENT_SESSION_COOKIE = "fo_student_session";

export async function callSupabaseRpc<T>(name: string, params: Record<string, unknown>): Promise<T> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      apikey: SUPABASE_PUBLISHABLE_KEY,
      Authorization: `Bearer ${SUPABASE_PUBLISHABLE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(params),
    cache: "no-store",
  });

  if (!response.ok) {
    throw new Error(`Supabase RPC ${name} failed with ${response.status}`);
  }
  return response.json() as Promise<T>;
}

export function readCookie(request: Request, name: string): string | null {
  const cookie = request.headers.get("cookie") ?? "";
  for (const part of cookie.split(";")) {
    const [key, ...value] = part.trim().split("=");
    if (key === name) return decodeURIComponent(value.join("="));
  }
  return null;
}

export function sessionCookie(token: string, request: Request): string {
  const secure = new URL(request.url).protocol === "https:" ? "; Secure" : "";
  return `${STUDENT_SESSION_COOKIE}=${encodeURIComponent(token)}; HttpOnly; SameSite=Strict; Path=/; Max-Age=28800${secure}`;
}

export function clearSessionCookie(request: Request): string {
  const secure = new URL(request.url).protocol === "https:" ? "; Secure" : "";
  return `${STUDENT_SESSION_COOKIE}=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0${secure}`;
}
