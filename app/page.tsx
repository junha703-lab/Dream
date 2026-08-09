"use client";

import { useMemo, useState } from "react";

type StudentView = "home" | "jobs" | "wallet" | "growth" | "room";

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

function Sidebar({ active, onChange }: { active: StudentView; onChange: (view: StudentView) => void }) {
  return (
    <aside className="sidebar">
      <Brand />
      <nav aria-label="학생 메뉴" className="side-nav">
        {studentNav.map((item) => (
          <button key={item.id} className={active === item.id ? "active" : ""} onClick={() => onChange(item.id)}>
            <span>{item.icon}</span>{item.label}
          </button>
        ))}
      </nav>
      <div className="side-tip">
        <span>💡</span>
        <strong>이번 주 작은 질문</strong>
        <p>어떤 일을 할 때 시간이 빨리 갔나요?</p>
      </div>
      <div className="side-profile"><Avatar small /><span><strong>김하늘</strong><small>은행원 · 5주차</small></span><button aria-label="설정">•••</button></div>
    </aside>
  );
}

function Topbar({ teacher, onRole }: { teacher: boolean; onRole: () => void }) {
  return (
    <header className="topbar">
      <div className="mobile-brand"><Brand /></div>
      <div className="week-pill"><span /> 2학기 · 5주차</div>
      <div className="top-actions">
        <button className="role-switch" onClick={onRole}>{teacher ? "학생 화면 보기" : "교사 화면 보기"}</button>
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

function StudentHome({ applied, setApplied, donated, onDonate }: { applied: number[]; setApplied: (id: number) => void; donated: boolean; onDonate: () => void }) {
  return (
    <>
      <section className="welcome-row"><div><span className="eyebrow">좋은 아침이에요</span><h1>하늘님의 오늘도 <em>멋진 탐험</em>이 기다려요!</h1><p>이번 주에는 새로운 일을 하나 경험해 볼까요?</p></div><div className="weather-note"><span>☀</span><p><strong>맑음 · 27°</strong><small>새로운 도전에 좋은 날!</small></p></div></section>
      <section className="profile-hero">
        <div className="profile-art"><div className="spark spark-a">✦</div><div className="spark spark-b">✦</div><Avatar /></div>
        <div className="profile-copy"><span className="job-chip">정보와 돈을 다루는 일</span><h2>우리 반 든든한 <em>은행원</em></h2><p>친구들의 저축을 돕고, 안전한 거래를 확인하는 금융업무 담당자예요.</p><div className="role-tasks"><span>✓ 저축 신청 확인</span><span>✓ 저축 상담</span><span>✓ 이상 거래 보고</span></div><button className="text-button">나의 직업 자세히 보기 →</button></div>
        <div className="week-mission"><span>이번 주 기본 업무</span><strong>저축 신청 3건 확인하기</strong><div className="mission-progress"><i style={{ width: "66%" }} /></div><small>2 / 3건 완료 · 조금만 더!</small></div>
      </section>
      <section className="money-grid"><MoneyCard label="현재 현금" value="2,450 꿈" detail="이번 주 +500" icon="₩" tone="purple" /><MoneyCard label="차곡차곡 저축" value="2,300 꿈" detail="다음 해금까지 700" icon="▥" tone="green" /><MoneyCard label="나의 자리" value="창가형 B-3" detail="주거비 300 / 주" icon="⌑" tone="orange" /></section>
      <section className="section-head"><div><span className="eyebrow">이번 주 일자리</span><h2>새로운 일을 탐험해 봐요</h2><p>기본직업과 달라도 괜찮아요. 마음이 가는 일을 골라보세요.</p></div><button>공고 전체 보기 →</button></section>
      <div className="job-grid home-jobs">{jobs.slice(0, 3).map((job) => <JobCard key={job.id} job={job} applied={applied.includes(job.id)} onApply={() => setApplied(job.id)} />)}</div>
      <div className="dashboard-grid"><RadarCard /><article className="panel savings-card"><div className="panel-title"><div><span className="eyebrow">저축 목표</span><h2>다음 마이룸 아이템</h2></div><span className="tiny-badge">독서형</span></div><div className="unlock-art"><div className="bookshelf"><span /><span /><span /><span /></div><div className="locked">🔒</div></div><h3>포근한 원목 책장</h3><p>저축 3,000꿈을 유지하면 해금돼요.</p><div className="fund-row"><span>2,300꿈 모음</span><strong>77%</strong></div><div className="progress purple"><i style={{ width: "77%" }} /></div><small className="remaining">700꿈만 더 모으면 만날 수 있어요!</small><button className="secondary-button">저축하러 가기</button></article></div>
      <CommunityCard donated={donated} onDonate={onDonate} />
      <section className="panel recent-panel"><div className="panel-title"><div><span className="eyebrow">나의 발자국</span><h2>최근에 이런 일을 했어요</h2></div><button>전체 기록 보기 →</button></div><div className="timeline"><div><span className="timeline-icon violet">✎</span><p><strong>친구 인터뷰 완료</strong><small>기자 업무 · 재미있음 5 · 협력적 소통 +3 · 공동체 +1</small></p><b>어제</b></div><div><span className="timeline-icon green">₩</span><p><strong>저축 상담 2건 확인</strong><small>기본직업 은행원 · 자기관리 +1 · 협력적 소통 +1</small></p><b>3일 전</b></div><div><span className="timeline-icon orange">✦</span><p><strong>행사 이름표 디자인</strong><small>디자인 업무 · 심미적 감성 +3 · 창의적 사고 +2</small></p><b>지난주</b></div></div></section>
    </>
  );
}

function JobsView({ applied, setApplied }: { applied: number[]; setApplied: (id: number) => void }) {
  const [filter, setFilter] = useState("전체");
  const filters = ["전체", "사람을 돕는 일", "만들고 해결하는 일", "정보와 돈", "알리고 표현하는 일"];
  return <><section className="page-heading"><span className="eyebrow">일자리 탐험</span><h1>이번 주, 어떤 일을 해볼까요?</h1><p>잘해야 하는 일이 아니라 궁금한 일을 골라보세요. 공고의 성장값은 활동에서 실제로 사용하는 2022 개정 교육과정 핵심역량을 기준으로 정했어요.</p></section><div className="filter-row">{filters.map((item) => <button key={item} onClick={() => setFilter(item)} className={filter === item ? "active" : ""}>{item}</button>)}</div><div className="jobs-summary"><strong>열린 공고 4개</strong><span>내가 지원한 공고 {applied.length}개</span><span>이번 주 남은 자리 7명</span></div><div className="job-grid all-jobs">{jobs.map((job) => <JobCard key={job.id} job={job} applied={applied.includes(job.id)} onApply={() => setApplied(job.id)} />)}</div></>;
}

function WalletView({ donated, onDonate }: { donated: boolean; onDonate: () => void }) {
  const [cash, setCash] = useState(2450);
  const [saving, setSaving] = useState(2300);
  const save = () => { if (cash >= 100) { setCash(cash - 100); setSaving(saving + 100); } };
  const withdraw = () => { if (saving >= 100) { setSaving(saving - 100); setCash(cash + 100); } };
  return <><section className="page-heading"><span className="eyebrow">나의 경제</span><h1>돈이 어디에서 오고, 어디로 갈까요?</h1><p>월급을 받고, 생활비를 내고, 저축과 나눔을 직접 경험해요.</p></section><div className="wallet-balance"><div><span>사용할 수 있는 현금</span><strong>{cash.toLocaleString()} <small>꿈</small></strong><p>이번 주 예상 월세 300꿈</p></div><div><span>차곡차곡 저축</span><strong>{saving.toLocaleString()} <small>꿈</small></strong><p>3,000꿈에 책장 해금</p></div><div className="wallet-actions"><button onClick={save}>+ 100꿈 저축 신청</button><button onClick={withdraw}>100꿈 출금 신청</button></div></div><div className="dashboard-grid wallet-grid"><article className="panel"><div className="panel-title"><div><span className="eyebrow">거래 기록</span><h2>최근 흐름</h2></div><button>전체 보기</button></div><div className="transaction-list"><div><span className="timeline-icon green">↙</span><p><strong>기본직업 월급</strong><small>5주차 주간 정산</small></p><b className="plus">+800꿈</b></div><div><span className="timeline-icon violet">▥</span><p><strong>저축</strong><small>은행원 확인 완료</small></p><b>-300꿈</b></div><div><span className="timeline-icon orange">⌂</span><p><strong>창가형 자리 주거비</strong><small>5주차 주간 정산</small></p><b>-300꿈</b></div><div><span className="timeline-icon violet">✦</span><p><strong>친구 인터뷰 보수</strong><small>업무 완료 자동 지급</small></p><b className="plus">+250꿈</b></div></div></article><article className="panel settlement-card"><span className="eyebrow">금요일 예상 정산</span><h2>이번 주 미리 보기</h2><div><span>은행원 월급</span><strong>+800꿈</strong></div><div><span>완료 공고 보수</span><strong>+300꿈</strong></div><div><span>창가형 주거비</span><strong>-300꿈</strong></div><hr /><div className="settlement-total"><span>예상 변화</span><strong>+800꿈</strong></div><small>정산은 선생님이 금요일에 한 번에 실행해요.</small></article></div><CommunityCard donated={donated} onDonate={onDonate} /></>;
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
  const [teacher, setTeacher] = useState(false);
  const [active, setActive] = useState<StudentView>("home");
  const [applied, setApplied] = useState<number[]>([]);
  const [donated, setDonated] = useState(false);
  const [toast, setToast] = useState("");
  const title = useMemo(() => studentNav.find((item) => item.id === active)?.label, [active]);
  const notify = (message: string) => { setToast(message); window.setTimeout(() => setToast(""), 2800); };
  const apply = (id: number) => { if (!applied.includes(id)) { setApplied([...applied, id]); notify("지원했어요! 실제 교실 활동에서 만나요."); } };
  const donate = () => { if (!donated) { setDonated(true); notify("공동체기금에 100꿈을 보탰어요. 고마워요!"); } };
  return (
    <div className={teacher ? "app teacher-mode" : "app"}>
      {!teacher && <Sidebar active={active} onChange={setActive} />}
      <div className="main-column">
        <Topbar teacher={teacher} onRole={() => setTeacher(!teacher)} />
        {teacher ? <TeacherDashboard onToast={notify} /> : <main className="content" aria-label={title}>{active === "home" && <StudentHome applied={applied} setApplied={apply} donated={donated} onDonate={donate} />}{active === "jobs" && <JobsView applied={applied} setApplied={apply} />}{active === "wallet" && <WalletView donated={donated} onDonate={donate} />}{active === "growth" && <GrowthView />}{active === "room" && <RoomView />}</main>}
        {!teacher && <nav className="mobile-nav" aria-label="모바일 학생 메뉴">{studentNav.map((item) => <button key={item.id} className={active === item.id ? "active" : ""} onClick={() => setActive(item.id)}><span>{item.icon}</span>{item.label.split(" ")[0]}</button>)}</nav>}
      </div>
      {toast && <div className="toast" role="status"><span>✓</span>{toast}</div>}
    </div>
  );
}
