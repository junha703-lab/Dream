"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";

type StudentView = "home" | "jobs" | "wallet" | "growth" | "room";
type StudentData = {
  student_id: string;
  display_name: string;
  student_number: number;
  first_login: boolean;
  account_status: string;
  basic_job: string | null;
  cash: number;
  savings: number;
  housing_name: string | null;
  growth_stage: number;
  basic_job_tasks_completed: number;
  jobs_completed: number;
  first_salary_received: boolean;
  first_saving_completed: boolean;
  saving_goal_reached: boolean;
  donation_count: number;
  total_donation: number;
  feature_unlocks: string[];
};

const viewFeature: Partial<Record<StudentView, string>> = { jobs: "job_board", wallet: "wallet", growth: "competencies", room: "my_room" };
const featureCopy: Record<string, { title: string; condition: string }> = {
  wallet: { title: "첫 월급과 지갑", condition: "첫 기본직업 업무를 완료하면 열립니다." },
  bank: { title: "은행과 저축", condition: "첫 월급을 받으면 열립니다." },
  housing: { title: "집과 자리", condition: "첫 저축을 완료하면 열립니다." },
  job_board: { title: "새로운 직업의 세계", condition: "기본직업 업무를 2회 완료하면 열립니다." },
  competencies: { title: "나의 여섯 가지 힘", condition: "서로 다른 업무를 4회 경험하면 열립니다." },
  my_room: { title: "나만의 공간", condition: "저축 3,000꿈 목표를 달성하면 열립니다." },
};
const stageNames = ["첫걸음", "생활 시작", "직업 탐험", "성장 발견", "나의 세계", "함께하는 사회"];

const jobs = [
  {
    id: 1,
    icon: "✦",
    tone: "violet",
    world: "알리고 표현하는 일",
    title: "학급 축제 포스터 만들기",
    description: "친구들이 축제를 한눈에 이해할 수 있는 포스터를 함께 만들어요.",
    people: "2명 모집",
    time: "40분",
    pay: 300,
    skills: ["창의적 사고 +3", "심미적 감성 +3", "협력적 소통 +1"],
  },
  {
    id: 2,
    icon: "▦",
    tone: "mint",
    world: "정보와 돈을 다루는 일",
    title: "우리 반 설문 결과 분석",
    description: "좋아하는 쉬는 시간 활동을 조사하고 보기 좋은 그래프로 정리해요.",
    people: "3명 모집",
    time: "30분",
    pay: 250,
    skills: ["지식정보처리 +3", "창의적 사고 +1", "협력적 소통 +1"],
  },
  {
    id: 3,
    icon: "⌂",
    tone: "orange",
    world: "만들고 해결하는 일",
    title: "학급문고 수납 방법 개선",
    description: "책을 더 쉽게 찾고 정리할 수 있는 새로운 방법을 제안해요.",
    people: "2명 모집",
    time: "35분",
    pay: 280,
    skills: ["지식정보처리 +2", "창의적 사고 +2", "공동체 +2"],
  },
  {
    id: 4,
    icon: "◉",
    tone: "blue",
    world: "사람을 돕는 일",
    title: "친구 복습 퀴즈 만들기",
    description: "이번 주에 배운 내용을 떠올릴 수 있는 재미있는 퀴즈를 만들어요.",
    people: "2명 모집",
    time: "25분",
    pay: 220,
    skills: ["지식정보처리 +2", "협력적 소통 +3", "자기관리 +1"],
  },
];

const competencyDefinitions = [
  {
    name: "자기관리 역량",
    short: "자기관리",
    value: 54,
    color: "#d75d88",
    icon: "◉",
    description: "자아정체성과 자신감을 가지고 자신의 삶과 진로를 스스로 설계하며, 필요한 기초 능력과 자질을 갖추어 자기주도적으로 살아가는 역량",
  },
  {
    name: "지식정보처리 역량",
    short: "지식정보처리",
    value: 61,
    color: "#8b6cc7",
    icon: "▦",
    description: "문제를 합리적으로 해결하기 위해 다양한 영역의 지식과 정보를 깊이 이해하고 비판적으로 탐구하며 활용하는 역량",
  },
  {
    name: "창의적 사고 역량",
    short: "창의적 사고",
    value: 65,
    color: "#f08a4b",
    icon: "✦",
    description: "폭넓은 기초 지식을 바탕으로 여러 분야의 지식·기술·경험을 융합적으로 활용하여 새로운 것을 창출하는 역량",
  },
  {
    name: "심미적 감성 역량",
    short: "심미적 감성",
    value: 58,
    color: "#e06f8f",
    icon: "♡",
    description: "인간에 대한 공감적 이해와 문화적 감수성을 바탕으로 삶의 의미와 가치를 성찰하고 향유하는 역량",
  },
  {
    name: "협력적 소통 역량",
    short: "협력적 소통",
    value: 73,
    color: "#2a9d75",
    icon: "↔",
    description: "다른 사람의 관점을 존중하고 경청하며 자신의 생각과 감정을 효과적으로 표현해 공동의 목적을 구현하는 역량",
  },
  {
    name: "공동체 역량",
    short: "공동체",
    value: 70,
    color: "#3f7bd9",
    icon: "◎",
    description: "개방적·포용적 가치와 태도로 지역·국가·세계 공동체의 지속 가능한 발전에 적극적이고 책임감 있게 참여하는 역량",
  },
] as const;

const skillRows = competencyDefinitions.map(({ short, value, color }) => [short, value, color] as const);

const studentNav: { id: StudentView; label: string; icon: string }[] = [
  { id: "home", label: "오늘의 생활", icon: "⌂" },
  { id: "jobs", label: "일자리 탐험", icon: "✦" },
  { id: "wallet", label: "나의 경제", icon: "₩" },
  { id: "growth", label: "진로 성장", icon: "◎" },
  { id: "room", label: "마이룸", icon: "▣" },
];

function Avatar({ small = false }: { small?: boolean }) {
  return (
    <div className={small ? "avatar avatar--small" : "avatar"} aria-label="은행원 캐릭터">
      <span className="avatar__hair" />
      <span className="avatar__face" />
      <span className="avatar__body" />
      <span className="avatar__tie" />
      <span className="avatar__case">₩</span>
    </div>
  );
}

function Brand() {
  return (
    <div className="brand">
      <span className="brand__mark">F</span>
      <span><strong>미래탐험대</strong><small>우리 반 진로생활</small></span>
    </div>
  );
}

function LoginVoyage({ onLogin, onTeacherPreview }: { onLogin: (student: StudentData) => void; onTeacherPreview: () => void }) {
  const [classCode, setClassCode] = useState("603");
  const [displayName, setDisplayName] = useState("");
  const [pin, setPin] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [voyaging, setVoyaging] = useState(false);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (!/^\d{4}$/.test(pin)) { setError("PIN은 숫자 4자리로 입력해 주세요."); return; }
    setLoading(true); setError("");
    try {
      const response = await fetch("/api/student", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ action: "login", classCode, displayName, pin }) });
      const result = await response.json();
      if (!response.ok || !result.ok) { setError(result.message ?? "로그인 정보를 다시 확인해 주세요."); setLoading(false); return; }
      setVoyaging(true);
      window.setTimeout(() => onLogin(result.student as StudentData), 950);
    } catch { setError("지금은 항해를 시작할 수 없어요. 잠시 후 다시 시도해 주세요."); setLoading(false); }
  };

  return <main className={`voyage-login ${voyaging ? "is-voyaging" : ""}`}>
    <div className="voyage-sky"><span className="cloud cloud-a" /><span className="cloud cloud-b" /><span className="sun-glow" /></div>
    <div className="voyage-copy"><div className="voyage-brand"><span>F</span> FUTURE ODYSSEY</div><p>교실에서 시작하는 나의 미래 항해</p><h1>작은 배 한 척으로<br /><em>나의 가능성</em>을 만나러 가요.</h1><div className="route-dots"><i /><i /><i /><span>새로운 항로</span></div></div>
    <div className="sea-layer sea-back" /><div className="sea-layer sea-front" />
    <div className="little-boat" aria-hidden="true"><span className="boat-sail" /><span className="boat-mast" /><span className="boat-hull" /></div>
    <section className="login-card" aria-label="학생 로그인">
      <span className="login-compass">✦</span><small>WELCOME ABOARD</small><h2>나의 미래 항해 시작</h2><p>선생님께 받은 정보를 입력해 주세요.</p>
      <form onSubmit={submit}>
        <label>학급코드<input inputMode="numeric" value={classCode} onChange={(e) => setClassCode(e.target.value.slice(0, 12))} placeholder="예: 603" autoComplete="organization" /></label>
        <label>이름<input value={displayName} onChange={(e) => setDisplayName(e.target.value.slice(0, 30))} placeholder="이름을 입력하세요" autoComplete="name" /></label>
        <label>숫자 4자리 PIN<input type="password" inputMode="numeric" pattern="[0-9]{4}" maxLength={4} value={pin} onChange={(e) => setPin(e.target.value.replace(/\D/g, "").slice(0, 4))} placeholder="● ● ● ●" autoComplete="current-password" /></label>
        {error && <div className="login-error" role="alert">! {error}</div>}
        <button className="voyage-button" disabled={loading || voyaging}>{loading ? "확인하고 있어요…" : voyaging ? "출항합니다…" : "항해 시작"}<span>→</span></button>
      </form>
      <div className="demo-logins"><span>체험 계정</span><button type="button" onClick={() => { setDisplayName("김민준"); setPin("3841"); }}>첫 로그인</button><button type="button" onClick={() => { setDisplayName("김하늘"); setPin("2580"); }}>성장 중</button></div>
      <button type="button" className="teacher-preview-link" onClick={onTeacherPreview}>교사 관리자 화면 미리보기</button>
    </section>
    <p className="voyage-footer">잔잔한 파도처럼 천천히, 나만의 속도로 성장해요.</p>
  </main>;
}

function PinSetup({ student, onComplete }: { student: StudentData; onComplete: (student: StudentData) => void }) {
  const [pin, setPin] = useState(""); const [confirm, setConfirm] = useState(""); const [error, setError] = useState(""); const [loading, setLoading] = useState(false);
  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (!/^\d{4}$/.test(pin)) { setError("숫자 4자리로 만들어 주세요."); return; }
    if (pin !== confirm) { setError("두 PIN이 서로 달라요. 다시 확인해 주세요."); return; }
    setLoading(true); setError("");
    const response = await fetch("/api/student", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ action: "change-pin", pin }) });
    const result = await response.json(); setLoading(false);
    if (!response.ok || !result.ok) { setError(result.message ?? "PIN을 바꾸지 못했어요."); return; }
    onComplete(result.student as StudentData);
  };
  return <main className="pin-page"><section className="pin-card"><span className="pin-lock">⌾</span><small>첫 항해 준비</small><h1>{student.display_name}님만의 비밀번호를<br />만들어 주세요.</h1><p>앞으로 Future Odyssey에 들어올 때 사용할 PIN이에요.</p><form onSubmit={submit}><label>새 PIN<input type="password" inputMode="numeric" maxLength={4} value={pin} onChange={(e) => setPin(e.target.value.replace(/\D/g, ""))} placeholder="○ ○ ○ ○" /></label><label>PIN 확인<input type="password" inputMode="numeric" maxLength={4} value={confirm} onChange={(e) => setConfirm(e.target.value.replace(/\D/g, ""))} placeholder="○ ○ ○ ○" /></label>{error && <div className="login-error" role="alert">! {error}</div>}<button className="voyage-button" disabled={loading}>{loading ? "저장하고 있어요…" : "내 비밀번호로 설정하기"}</button></form><div className="pin-guide">🔒 친구에게 알려주지 마세요. 선생님도 지금 PIN을 볼 수 없어요.</div></section></main>;
}

function FirstOnboarding({ student, onStart }: { student: StudentData; onStart: () => void }) {
  return <main className="onboarding-page"><div className="onboarding-route"><i /><i /><i /></div><section className="onboarding-card"><span className="eyebrow">WELCOME TO FUTURE ODYSSEY</span><h1>{student.display_name}님의 첫 항해를<br />환영합니다!</h1><p>처음에는 작은 배 한 척이면 충분해요.<br />첫 직업에서 하나씩 경험하며 새로운 항로를 만나 보세요.</p><div className="first-job-card"><Avatar /><div><small>나의 첫 직업</small><h2>{student.basic_job ?? "직업 배정 대기"}</h2><span>첫 번째 업무</span><strong>{student.basic_job === "기자" ? "우리 반의 좋은 소식 한 가지 찾기" : "기본직업 업무를 확인하기"}</strong></div></div><button className="voyage-button" onClick={onStart}>나의 미래여정 시작 <span>→</span></button></section></main>;
}

function LockedFeature({ feature, student, onBack }: { feature: string; student: StudentData; onBack: () => void }) {
  const copy = featureCopy[feature] ?? { title: "아직 만나지 않은 항로", condition: "조금 더 경험하면 열립니다." };
  const current = feature === "job_board" ? student.basic_job_tasks_completed : feature === "my_room" ? student.savings : student.basic_job_tasks_completed;
  const target = feature === "job_board" ? 2 : feature === "my_room" ? 3000 : 4;
  return <main className="locked-page"><section className="locked-route-card"><div className="locked-compass">⌖</div><span className="eyebrow">아직 닿지 않은 항로</span><h1>{copy.title}</h1><p>{copy.condition}</p><div className="unlock-progress-copy"><span>현재 진행</span><strong>{current.toLocaleString()} / {target.toLocaleString()}</strong></div><div className="progress purple"><i style={{ width: `${Math.min(100, current / target * 100)}%` }} /></div><small>복잡한 점수 대신 실제로 해본 활동만 세어요.</small><button className="secondary-button" onClick={onBack}>오늘의 생활로 돌아가기</button></section></main>;
}

function Sidebar({ active, onChange, student, onLogout }: { active: StudentView; onChange: (view: StudentView) => void; student: StudentData; onLogout: () => void }) {
  const lockedViews = studentNav.filter((item) => viewFeature[item.id] && !student.feature_unlocks.includes(viewFeature[item.id]!)).slice(0, 2).map((item) => item.id);
  const visibleItems = studentNav.filter((item) => !viewFeature[item.id] || student.feature_unlocks.includes(viewFeature[item.id]!) || lockedViews.includes(item.id));
  return (
    <aside className="sidebar">
      <Brand />
      <nav aria-label="학생 메뉴" className="side-nav">
        {visibleItems.map((item) => {
          const locked = Boolean(viewFeature[item.id] && !student.feature_unlocks.includes(viewFeature[item.id]!));
          return <button key={item.id} className={`${active === item.id ? "active" : ""} ${locked ? "nav-locked" : ""}`} onClick={() => onChange(item.id)}>
            <span>{locked ? "◌" : item.icon}</span><span className="nav-copy">{item.label}{locked && <small>{featureCopy[viewFeature[item.id]!]?.condition}</small>}</span>
          </button>
        })}
      </nav>
      <div className="side-tip">
        <span>💡</span>
        <strong>이번 주 작은 질문</strong>
        <p>어떤 일을 할 때 시간이 빨리 갔나요?</p>
      </div>
      <div className="side-profile"><Avatar small /><span><strong>{student.display_name}</strong><small>{student.basic_job ?? "직업 대기"} · {stageNames[student.growth_stage - 1]}</small></span><button aria-label="로그아웃" title="로그아웃" onClick={onLogout}>↪</button></div>
    </aside>
  );
}

function Topbar({ teacher, onRole }: { teacher: boolean; onRole?: () => void }) {
  return (
    <header className="topbar">
      <div className="mobile-brand"><Brand /></div>
      <div className="week-pill"><span /> 2학기 · 5주차</div>
      <div className="top-actions">
        {onRole && <button className="role-switch" onClick={onRole}>{teacher ? "로그인 화면으로" : "교사 화면 보기"}</button>}
        <button className="icon-button" aria-label="알림">♢<i /></button>
      </div>
    </header>
  );
}

function MoneyCard({ label, value, detail, icon, tone }: { label: string; value: string; detail: string; icon: string; tone: string }) {
  return (
    <article className="money-card">
      <span className={`round-icon ${tone}`}>{icon}</span>
      <div><p>{label}</p><strong>{value}</strong><small>{detail}</small></div>
    </article>
  );
}

function JobCard({ job, applied, onApply }: { job: (typeof jobs)[number]; applied: boolean; onApply: () => void }) {
  return (
    <article className="job-card">
      <div className="job-card__head"><span className={`job-icon ${job.tone}`}>{job.icon}</span><span className="world-label">{job.world}</span><button aria-label="공고 저장">♡</button></div>
      <h3>{job.title}</h3>
      <p>{job.description}</p>
      <div className="job-meta"><span>♙ {job.people}</span><span>◷ {job.time}</span><strong>+{job.pay.toLocaleString()} 꿈</strong></div>
      <div className="skill-tags">{job.skills.map((skill) => <span key={skill}>{skill}</span>)}</div>
      <button className={applied ? "apply-button applied" : "apply-button"} onClick={onApply}>{applied ? "지원 완료 ✓" : "이 일 경험해 보기"}</button>
    </article>
  );
}

function RadarCard() {
  return (
    <article className="panel growth-card">
      <div className="panel-title"><div><span className="eyebrow">나의 역량</span><h2>이만큼 자랐어요</h2></div><button>자세히 보기 →</button></div>
      <div className="growth-body">
        <div className="radar-wrap" aria-label="역량 육각형 그래프">
          <div className="radar-grid grid-one" /><div className="radar-grid grid-two" /><div className="radar-grid grid-three" />
          <div className="radar-shape" />
          <span className="radar-label top">협력적 소통</span><span className="radar-label tr">창의적 사고</span><span className="radar-label br">심미적 감성</span>
          <span className="radar-label bottom">공동체</span><span className="radar-label bl">자기관리</span><span className="radar-label tl">지식정보처리</span>
        </div>
        <div className="skill-list">
          {skillRows.map(([label, value, color]) => <div className="skill-row" key={label}><span>{label}</span><div><i style={{ width: `${value}%`, background: color }} /></div><strong>{value}</strong></div>)}
        </div>
      </div>
      <div className="growth-note"><span>↗</span><p><strong>협력적 소통 역량이 가장 많이 자랐어요!</strong><small>친구 인터뷰와 은행 상담에서 경청하고 설명한 경험 덕분이에요.</small></p></div>
    </article>
  );
}

function CommunityCard({ donated, onDonate }: { donated: boolean; onDonate: () => void }) {
  return (
    <article className="panel community-card">
      <div className="community-visual"><span>우리 반</span><strong>피구놀이</strong><div className="ball">●</div></div>
      <div className="community-copy">
        <span className="eyebrow">함께 만드는 공동체 목표</span><h2>우리 반 피구놀이를 열어요!</h2><p>금액과 참여 조건을 모두 채우면 금요일에 함께 즐길 수 있어요.</p>
        <div className="fund-row"><span>현재 기금</span><strong>8,350 <small>/ 10,000 꿈</small></strong></div>
        <div className="progress"><i style={{ width: "83.5%" }} /></div>
        <div className="fund-row participation"><span>2회 이상 기부한 친구</span><strong>23 / 25명</strong></div>
        <button className={donated ? "donate-button done" : "donate-button"} onClick={onDonate}>{donated ? "오늘의 기부 완료 ✓" : "100꿈 함께 보태기"}</button>
      </div>
    </article>
  );
}

function StarterHome({ student, onCompleteTask, busy }: { student: StudentData; onCompleteTask: () => void; busy: boolean }) {
  const completed = student.basic_job_tasks_completed;
  return <>
    <section className="welcome-row"><div><span className="eyebrow">{stageNames[student.growth_stage - 1]} · 첫 항해</span><h1>{student.display_name}님의 세계는 지금부터 <em>천천히</em> 넓어져요.</h1><p>오늘은 첫 직업과 첫 번째 업무에만 집중해 보세요.</p></div></section>
    <section className="profile-hero starter-hero"><div className="profile-art"><div className="spark spark-a">✦</div><Avatar /></div><div className="profile-copy"><span className="job-chip">나의 첫 직업</span><h2>우리 반의 <em>{student.basic_job ?? "새로운 역할"}</em></h2><p>{student.basic_job === "기자" ? "우리 반의 좋은 소식을 발견하고 친구들에게 알기 쉽게 전하는 역할이에요." : "교실에서 맡은 첫 역할을 경험하며 나의 강점을 찾아가요."}</p><div className="role-tasks"><span>✓ 주변을 자세히 살펴보기</span><span>✓ 친구의 이야기를 잘 듣기</span></div></div><div className="week-mission"><span>첫 번째 업무</span><strong>{student.basic_job === "기자" ? "우리 반의 좋은 소식 한 가지 찾기" : "기본직업 업무 확인하기"}</strong><div className="mission-progress"><i style={{ width: completed > 0 ? "100%" : "8%" }} /></div><small>{completed > 0 ? "완료했어요! 첫 월급을 확인해 보세요." : "실제 교실 활동을 마치고 완료를 눌러요."}</small></div></section>
    <section className="first-task-panel"><div className="first-task-route"><span className="route-start">⚑</span><i /><span className="route-lock">₩</span><i /><span className="route-lock">▥</span></div><div><span className="eyebrow">다음에 열릴 항로</span><h2>첫 업무를 마치면 지갑과 은행을 발견해요</h2><p>첫 월급 800꿈이 지급되고, 내가 번 돈을 확인하고 저축할 수 있게 돼요.</p><button className="apply-button" onClick={onCompleteTask} disabled={busy || completed > 0}>{busy ? "기록하고 있어요…" : completed > 0 ? "첫 업무 완료 ✓" : "첫 업무 완료하기"}</button></div></section>
  </>;
}

function StudentHome({ student, applied, setApplied, donated, onDonate }: { student: StudentData; applied: number[]; setApplied: (id: number) => void; donated: boolean; onDonate: () => void }) {
  return (
    <>
      <section className="welcome-row"><div><span className="eyebrow">{stageNames[student.growth_stage - 1]} · 좋은 아침이에요</span><h1>{student.display_name}님의 오늘도 <em>멋진 탐험</em>이 기다려요!</h1><p>이번 주에는 새로운 일을 하나 경험해 볼까요?</p></div><div className="weather-note"><span>☀</span><p><strong>맑음 · 27°</strong><small>새로운 도전에 좋은 날!</small></p></div></section>
      <section className="profile-hero">
        <div className="profile-art"><div className="spark spark-a">✦</div><div className="spark spark-b">✦</div><Avatar /></div>
        <div className="profile-copy"><span className="job-chip">나의 기본직업</span><h2>우리 반의 <em>{student.basic_job ?? "새로운 역할"}</em></h2><p>맡은 역할을 꾸준히 경험하며 나에게 맞는 일과 강점을 발견해요.</p><div className="role-tasks"><span>✓ 기본 업무 확인</span><span>✓ 친구와 협력</span><span>✓ 경험 기록</span></div><button className="text-button">나의 직업 자세히 보기 →</button></div>
        <div className="week-mission"><span>기본직업 업무 경험</span><strong>{student.basic_job_tasks_completed}번의 일을 해봤어요</strong><div className="mission-progress"><i style={{ width: `${Math.min(100, student.basic_job_tasks_completed / 4 * 100)}%` }} /></div><small>경험할수록 새로운 항로가 열려요.</small></div>
      </section>
      <section className="money-grid"><MoneyCard label="현재 현금" value={`${student.cash.toLocaleString()} 꿈`} detail="내가 일해서 번 돈" icon="₩" tone="purple" />{student.feature_unlocks.includes("bank") && <MoneyCard label="차곡차곡 저축" value={`${student.savings.toLocaleString()} 꿈`} detail={`마이룸까지 ${Math.max(0, 3000 - student.savings).toLocaleString()}`} icon="▥" tone="green" />}{student.feature_unlocks.includes("housing") && <MoneyCard label="나의 자리" value={student.housing_name ?? "자리 배정 대기"} detail="집과 생활 항로" icon="⌑" tone="orange" />}</section>
      {student.feature_unlocks.includes("job_board") && <><section className="section-head"><div><span className="eyebrow">이번 주 일자리</span><h2>새로운 일을 탐험해 봐요</h2><p>기본직업과 달라도 괜찮아요. 마음이 가는 일을 골라보세요.</p></div><button>공고 전체 보기 →</button></section><div className="job-grid home-jobs">{jobs.slice(0, 3).map((job) => <JobCard key={job.id} job={job} applied={applied.includes(job.id)} onApply={() => setApplied(job.id)} />)}</div></>}
      <div className={`dashboard-grid ${student.feature_unlocks.includes("competencies") ? "" : "single-card"}`}>{student.feature_unlocks.includes("competencies") && <RadarCard />}<article className="panel savings-card"><div className="panel-title"><div><span className="eyebrow">저축 목표</span><h2>다음 마이룸 아이템</h2></div><span className="tiny-badge">독서형</span></div><div className="unlock-art"><div className="bookshelf"><span /><span /><span /><span /></div><div className="locked">🔒</div></div><h3>포근한 원목 책장</h3><p>저축 3,000꿈을 유지하면 해금돼요.</p><div className="fund-row"><span>{student.savings.toLocaleString()}꿈 모음</span><strong>{Math.min(100, Math.round(student.savings / 3000 * 100))}%</strong></div><div className="progress purple"><i style={{ width: `${Math.min(100, student.savings / 3000 * 100)}%` }} /></div><small className="remaining">{Math.max(0, 3000 - student.savings).toLocaleString()}꿈만 더 모으면 만날 수 있어요!</small><button className="secondary-button">저축하러 가기</button></article></div>
      {student.feature_unlocks.includes("community_fund") && <CommunityCard donated={donated} onDonate={onDonate} />}
      <section className="panel recent-panel"><div className="panel-title"><div><span className="eyebrow">나의 발자국</span><h2>최근에 이런 일을 했어요</h2></div><button>전체 기록 보기 →</button></div><div className="timeline"><div><span className="timeline-icon violet">✎</span><p><strong>친구 인터뷰 완료</strong><small>기자 업무 · 재미있음 5 · 협력적 소통 +3 · 공동체 +1</small></p><b>어제</b></div><div><span className="timeline-icon green">₩</span><p><strong>저축 상담 2건 확인</strong><small>기본직업 은행원 · 자기관리 +1 · 협력적 소통 +1</small></p><b>3일 전</b></div><div><span className="timeline-icon orange">✦</span><p><strong>행사 이름표 디자인</strong><small>디자인 업무 · 심미적 감성 +3 · 창의적 사고 +2</small></p><b>지난주</b></div></div></section>
    </>
  );
}

function JobsView({ applied, setApplied }: { applied: number[]; setApplied: (id: number) => void }) {
  const [filter, setFilter] = useState("전체");
  const filters = ["전체", "사람을 돕는 일", "만들고 해결하는 일", "정보와 돈", "알리고 표현하는 일"];
  return <><section className="page-heading"><span className="eyebrow">일자리 탐험</span><h1>이번 주, 어떤 일을 해볼까요?</h1><p>잘해야 하는 일이 아니라 궁금한 일을 골라보세요. 공고의 성장값은 활동에서 실제로 사용하는 2022 개정 교육과정 핵심역량을 기준으로 정했어요.</p></section><div className="filter-row">{filters.map((item) => <button key={item} onClick={() => setFilter(item)} className={filter === item ? "active" : ""}>{item}</button>)}</div><div className="jobs-summary"><strong>열린 공고 4개</strong><span>내가 지원한 공고 {applied.length}개</span><span>이번 주 남은 자리 7명</span></div><div className="job-grid all-jobs">{jobs.map((job) => <JobCard key={job.id} job={job} applied={applied.includes(job.id)} onApply={() => setApplied(job.id)} />)}</div></>;
}

function WalletView({ student, donated, onDonate, onSave, busy }: { student: StudentData; donated: boolean; onDonate: () => void; onSave: () => void; busy: boolean }) {
  const bankOpen = student.feature_unlocks.includes("bank");
  const housingOpen = student.feature_unlocks.includes("housing");
  return <><section className="page-heading"><span className="eyebrow">나의 경제</span><h1>돈이 어디에서 오고, 어디로 갈까요?</h1><p>월급을 받고, 생활비를 내고, 저축과 나눔을 직접 경험해요.</p></section><div className="wallet-balance"><div><span>사용할 수 있는 현금</span><strong>{student.cash.toLocaleString()} <small>꿈</small></strong><p>{housingOpen ? "이번 주 예상 월세 300꿈" : "첫 월급부터 차근차근 시작해요"}</p></div><div className={bankOpen ? "" : "soft-locked"}><span>차곡차곡 저축</span><strong>{bankOpen ? student.savings.toLocaleString() : "—"} <small>꿈</small></strong><p>{bankOpen ? "3,000꿈에 마이룸 해금" : "첫 월급을 받으면 은행이 열려요"}</p></div><div className="wallet-actions"><button onClick={onSave} disabled={!bankOpen || busy || student.cash < 100}>{busy ? "처리 중…" : "+ 100꿈 저축하기"}</button><button disabled>출금은 은행원 확인 후 가능</button></div></div><div className="dashboard-grid wallet-grid"><article className="panel"><div className="panel-title"><div><span className="eyebrow">거래 기록</span><h2>최근 흐름</h2></div></div><div className="transaction-list"><div><span className="timeline-icon green">↙</span><p><strong>기본직업 첫 월급</strong><small>기본 업무 완료 후 자동 지급</small></p><b className="plus">+800꿈</b></div>{student.first_saving_completed && <div><span className="timeline-icon violet">▥</span><p><strong>첫 저축</strong><small>나의 경제 경험이 한 칸 넓어졌어요</small></p><b>-100꿈</b></div>}{housingOpen && <div><span className="timeline-icon orange">⌂</span><p><strong>{student.housing_name ?? "나의 자리"}</strong><small>집과 자리 기능이 열렸어요</small></p><b>발견</b></div>}</div></article><article className="panel settlement-card"><span className="eyebrow">나의 다음 항로</span><h2>{student.savings >= 3000 ? "마이룸이 열렸어요!" : "저축 목표 3,000꿈"}</h2><div><span>현재 저축</span><strong>{student.savings.toLocaleString()}꿈</strong></div><div><span>남은 금액</span><strong>{Math.max(0, 3000 - student.savings).toLocaleString()}꿈</strong></div><div className="progress purple"><i style={{ width: `${Math.min(100, student.savings / 3000 * 100)}%` }} /></div><small>돈을 쓰는 대신 저축을 유지하면 나만의 공간이 열려요.</small></article></div>{student.feature_unlocks.includes("community_fund") && <CommunityCard donated={donated} onDonate={onDonate} />}</>;
}

function GrowthView() {
  return <><section className="page-heading"><span className="eyebrow">진로 성장</span><h1>직업 이름보다, 내가 해본 일을 모아요</h1><p>좋아했던 일과 자주 사용한 핵심역량이 쌓이면 나만의 진로 지도가 완성돼요.</p></section><div className="growth-layout"><RadarCard /><article className="panel experience-card"><span className="eyebrow">나의 경험 지도</span><h2>이번 학기 13번의 경험</h2><div className="experience-orbits"><div className="orbit-center"><Avatar small /></div><span className="orbit one">금융 <b>7</b></span><span className="orbit two">소통 <b>3</b></span><span className="orbit three">디자인 <b>2</b></span><span className="orbit four">기획 <b>1</b></span></div><div className="badge-row"><span>🏦<small>금융 경험</small></span><span>🎙️<small>소통 발견</small></span><span>🧭<small>탐험가</small></span><span className="locked-badge">🔒<small>다음 배지</small></span></div></article></div><article className="panel reflection-card"><div><span className="eyebrow">나의 발견 노트</span><h2>나는 이런 순간이 좋았어요</h2></div><blockquote>“친구의 이야기를 잘 듣고 복잡한 내용을 쉽게 설명했을 때 뿌듯했어요.”</blockquote><div><strong>좋아한 활동</strong><span>친구 인터뷰</span><span>저축 상담</span><span>자료 정리</span></div></article><section className="competency-section"><div className="competency-heading"><div><span className="eyebrow">2022 개정 교육과정 핵심역량</span><h2>여섯 가지 힘을 골고루 발견해요</h2><p>점수는 서로 비교하는 순위가 아니라, 공고를 수행하며 어떤 힘을 사용했는지 보여주는 성장 기록이에요.</p></div><span>교육과정 기반</span></div><div className="competency-grid">{competencyDefinitions.map((item) => <article className="competency-card" key={item.name}><span className="competency-icon" style={{ color: item.color, background: `${item.color}18` }}>{item.icon}</span><div><h3>{item.name}</h3><p>{item.description}</p></div></article>)}</div></section></>;
}

function RoomView() {
  const [style, setStyle] = useState("독서형");
  return <><section className="page-heading room-heading"><div><span className="eyebrow">나의 공간</span><h1>취향을 담는 작은 방</h1><p>저축으로 해금한 아이템을 골라 나답게 꾸며보세요.</p></div><div className="room-level"><span>다음 해금</span><strong>책장까지 700꿈</strong></div></section><div className="room-layout"><div className={`room-scene style-${style}`}><div className="room-wall"><div className="window"><i /><span /></div><div className="poster">MY<br />DREAM</div><div className="shelf"><i /><i /><i /></div></div><div className="room-floor"><div className="rug" /><div className="desk"><span>✎</span></div><div className="chair" /><div className="plant">♣</div><div className="room-avatar"><Avatar /></div></div><div className="room-label">김하늘의 {style} 마이룸</div></div><aside className="panel room-controls"><span className="eyebrow">스타일 고르기</span><h2>오늘의 분위기</h2>{["독서형", "자연형", "디지털형", "예술형", "메이커형"].map((item) => <button key={item} className={style === item ? "active" : ""} onClick={() => setStyle(item)}><i className={`swatch swatch-${item}`} /><span><strong>{item}</strong><small>{item === "독서형" ? "차분하고 포근하게" : item === "자연형" ? "초록빛으로 편안하게" : "나의 취향을 또렷하게"}</small></span>{style === item && <b>✓</b>}</button>)}</aside></div></>;
}

function TeacherDashboard({ onToast }: { onToast: (message: string) => void }) {
  const [weekStarted, setWeekStarted] = useState(false);
  const [settled, setSettled] = useState(false);
  const startWeek = () => { setWeekStarted(true); onToast("5주차 공고 4개를 열었어요."); };
  const settle = () => { setSettled(true); onToast("5주차 정산을 안전하게 완료했어요."); };
  return <main className="teacher-shell"><section className="teacher-welcome"><div><span className="eyebrow">솔빛초 5학년 2반</span><h1>선생님, 이번 주도 <em>한눈에</em> 살펴보세요.</h1><p>잘 돌아가는 일은 시스템이 처리하고, 도움이 필요한 학생만 알려드릴게요.</p></div><div className="teacher-date"><span>이번 운영 주차</span><strong>2학기 · 5주차</strong><small>{weekStarted ? "진행 중 · 금요일 정산 예정" : "시작 전 · 공고를 준비했어요"}</small></div></section><section className="teacher-actions"><button className={weekStarted ? "done" : "primary"} onClick={startWeek}><span>▶</span><p><strong>{weekStarted ? "이번 주 진행 중" : "이번 주 시작"}</strong><small>{weekStarted ? "공고 4개가 열려 있어요" : "추천 공고를 열고 활동 시작"}</small></p></button><button className={settled ? "done" : ""} onClick={settle}><span>✓</span><p><strong>{settled ? "정산 완료" : "이번 주 정산"}</strong><small>급여·월세·보수 한 번에 처리</small></p></button><button onClick={() => onToast("공고 템플릿 12개를 확인할 수 있어요.")}><span>✦</span><p><strong>공고 관리</strong><small>템플릿 12개 · 열린 공고 4개</small></p></button><button className="alert-action" onClick={() => onToast("확인이 필요한 학생 3명을 표시했어요.")}><span>!</span><p><strong>예외 확인</strong><small>도움이 필요한 학생 3명</small></p><b>3</b></button></section><section className="teacher-stats"><article><span className="round-icon purple">♙</span><p>전체 학생<strong>25명</strong><small>모두 접속 완료</small></p></article><article><span className="round-icon green">↗</span><p>공고 참여율<strong>84%</strong><small>지난주보다 8% ↑</small></p></article><article><span className="round-icon orange">✓</span><p>완료된 업무<strong>18건</strong><small>진행 중 7건</small></p></article><article><span className="round-icon blue">♥</span><p>공동체기금<strong>8,350꿈</strong><small>목표의 83.5%</small></p></article></section><div className="teacher-grid"><article className="panel participation-panel"><div className="panel-title"><div><span className="eyebrow">이번 주 참여</span><h2>학생 활동 현황</h2></div><button>학생 전체 보기 →</button></div><div className="donut-row"><div className="donut"><span><strong>21</strong><small>/ 25명</small></span></div><div className="legend"><p><i className="legend-a" />공고 참여<strong>21명</strong></p><p><i className="legend-b" />아직 미참여<strong>4명</strong></p><p><i className="legend-c" />업무 완료<strong>18명</strong></p></div></div><div className="nudge"><span>💬</span><p><strong>4명의 학생이 아직 공고를 고르지 않았어요.</strong><small>부담 없는 공고를 함께 살펴보도록 안내해 보세요.</small></p><button>학생 확인</button></div></article><article className="panel exceptions"><div className="panel-title"><div><span className="eyebrow red">확인 필요</span><h2>딱 3가지만 봐주세요</h2></div><span className="count-badge">3</span></div><div className="exception-list"><div><span className="exception-icon red">!</span><p><strong>월세 납부가 어려워요</strong><small>박민준 · 예상 잔액 120꿈</small></p><button>확인</button></div><div><span className="exception-icon orange">◷</span><p><strong>2주 연속 공고 미참여</strong><small>이서윤 · 마지막 참여 3주차</small></p><button>확인</button></div><div><span className="exception-icon violet">⇄</span><p><strong>자리 이동 신청이 겹쳤어요</strong><small>협업형 C-2 · 신청 학생 2명</small></p><button>확인</button></div></div><button className="secondary-button full">모든 예외 자세히 보기</button></article></div><div className="teacher-grid lower"><article className="panel week-board"><div className="panel-title"><div><span className="eyebrow">5주차 공고</span><h2>일자리 진행 상황</h2></div><button>공고 관리 →</button></div>{jobs.slice(0, 3).map((job, index) => <div className="teacher-job" key={job.id}><span className={`job-icon ${job.tone}`}>{job.icon}</span><p><strong>{job.title}</strong><small>{["2명 선정 · 1명 완료", "3명 선정 · 3명 진행 중", "2명 선정 · 2명 완료"][index]}</small></p><div className="mini-progress"><i style={{ width: ["50%", "35%", "100%"][index] }} /></div><b>{["1/2", "0/3", "2/2"][index]}</b></div>)}</article><article className="panel fund-teacher"><div><span className="eyebrow">공동체 목표</span><h2>피구놀이까지 거의 다 왔어요</h2><p>기금은 충분하지만 2명의 학생이 한 번 더 참여하면 목표가 열려요.</p></div><div className="goal-ring"><span><strong>84%</strong><small>8,350꿈</small></span></div><div className="fund-checks"><p className="complete">✓ 금액 조건 <strong>8,350 / 8,000</strong></p><p>○ 참여 조건 <strong>23 / 25명</strong></p></div><button onClick={() => onToast("공동체 목표 안내를 학생 화면에 보냈어요.")}>학생에게 목표 다시 알리기</button></article></div></main>;
}

export default function Home() {
  const [teacherPreview, setTeacherPreview] = useState(false);
  const [student, setStudent] = useState<StudentData | null>(null);
  const [checkingSession, setCheckingSession] = useState(true);
  const [showOnboarding, setShowOnboarding] = useState(false);
  const [lockedFeature, setLockedFeature] = useState("");
  const [busy, setBusy] = useState(false);
  const [active, setActive] = useState<StudentView>("home");
  const [applied, setApplied] = useState<number[]>([]);
  const [donated, setDonated] = useState(false);
  const [toast, setToast] = useState("");
  const title = useMemo(() => studentNav.find((item) => item.id === active)?.label, [active]);
  const notify = (message: string) => { setToast(message); window.setTimeout(() => setToast(""), 2800); };
  const apply = (id: number) => { if (!applied.includes(id)) { setApplied([...applied, id]); notify("지원했어요! 실제 교실 활동에서 만나요."); } };
  const donate = () => { if (!donated) { setDonated(true); notify("공동체기금에 100꿈을 보탰어요. 고마워요!"); } };

  useEffect(() => {
    fetch("/api/student", { cache: "no-store" }).then(async (response) => {
      if (!response.ok) return;
      const result = await response.json();
      if (result.ok) setStudent(result.student as StudentData);
    }).finally(() => setCheckingSession(false));
  }, []);

  const postAction = async (action: string, extra: Record<string, unknown> = {}) => {
    setBusy(true);
    try {
      const response = await fetch("/api/student", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ action, ...extra }) });
      const result = await response.json();
      if (!response.ok || !result.ok) { notify(result.message ?? "처리하지 못했어요."); return null; }
      if (result.student) setStudent(result.student as StudentData);
      return result.student as StudentData | undefined;
    } finally { setBusy(false); }
  };
  const completeTask = async () => {
    const before = new Set(student?.feature_unlocks ?? []); const updated = await postAction("complete-task");
    if (updated) notify(!before.has("wallet") && updated.feature_unlocks.includes("wallet") ? "새로운 항로 발견! 첫 월급과 지갑이 열렸어요." : "기본직업 업무를 기록했어요.");
  };
  const saveMoney = async () => {
    const before = new Set(student?.feature_unlocks ?? []); const updated = await postAction("save", { amount: 100 });
    if (updated) notify(!before.has("housing") && updated.feature_unlocks.includes("housing") ? "새로운 항로 발견! 집과 자리 기능이 열렸어요." : "100꿈을 안전하게 저축했어요.");
  };
  const logout = async () => { await postAction("logout"); setStudent(null); setTeacherPreview(false); setActive("home"); setLockedFeature(""); };
  const changeView = (view: StudentView) => {
    if (!student) return;
    const required = viewFeature[view];
    if (required && !student.feature_unlocks.includes(required)) { setLockedFeature(required); return; }
    setLockedFeature(""); setActive(view);
  };

  if (checkingSession) return <main className="session-loading"><Brand /><div className="loading-wave"><i /><i /><i /></div><p>나의 항해 기록을 불러오고 있어요…</p></main>;
  if (teacherPreview) return <div className="app teacher-mode"><div className="main-column"><Topbar teacher onRole={() => setTeacherPreview(false)} /><TeacherDashboard onToast={notify} /></div>{toast && <div className="toast" role="status"><span>✓</span>{toast}</div>}</div>;
  if (!student) return <LoginVoyage onLogin={setStudent} onTeacherPreview={() => setTeacherPreview(true)} />;
  if (student.first_login) return <PinSetup student={student} onComplete={(updated) => { setStudent(updated); setShowOnboarding(true); }} />;
  if (showOnboarding) return <FirstOnboarding student={student} onStart={() => setShowOnboarding(false)} />;

  const lockedViews = studentNav.filter((item) => viewFeature[item.id] && !student.feature_unlocks.includes(viewFeature[item.id]!)).slice(0, 2).map((item) => item.id);
  const mobileItems = studentNav.filter((item) => !viewFeature[item.id] || student.feature_unlocks.includes(viewFeature[item.id]!) || lockedViews.includes(item.id));
  return (
    <div className="app">
      <Sidebar active={active} onChange={changeView} student={student} onLogout={logout} />
      <div className="main-column">
        <Topbar teacher={false} />
        <main className="content" aria-label={title}>{lockedFeature ? <LockedFeature feature={lockedFeature} student={student} onBack={() => { setLockedFeature(""); setActive("home"); }} /> : <>{active === "home" && (student.feature_unlocks.includes("wallet") ? <StudentHome student={student} applied={applied} setApplied={apply} donated={donated} onDonate={donate} /> : <StarterHome student={student} onCompleteTask={completeTask} busy={busy} />)}{active === "jobs" && <JobsView applied={applied} setApplied={apply} />}{active === "wallet" && <WalletView student={student} donated={donated} onDonate={donate} onSave={saveMoney} busy={busy} />}{active === "growth" && <GrowthView />}{active === "room" && <RoomView />}</>}</main>
        <nav className="mobile-nav" aria-label="모바일 학생 메뉴">{mobileItems.map((item) => { const locked = Boolean(viewFeature[item.id] && !student.feature_unlocks.includes(viewFeature[item.id]!)); return <button key={item.id} className={`${active === item.id ? "active" : ""} ${locked ? "nav-locked" : ""}`} onClick={() => changeView(item.id)}><span>{locked ? "◌" : item.icon}</span>{item.label.split(" ")[0]}</button> })}</nav>
      </div>
      {toast && <div className="toast" role="status"><span>✓</span>{toast}</div>}
    </div>
  );
}
