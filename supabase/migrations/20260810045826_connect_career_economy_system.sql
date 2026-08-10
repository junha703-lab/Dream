-- Future Odyssey full career/economy workflow.
-- All public tables are API-denied; students and teachers use narrowly granted RPCs.

begin;

create table if not exists public.teacher_profiles (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classrooms(id) on delete cascade,
  display_name text not null,
  account_status text not null default 'active' check (account_status in ('active','disabled')),
  created_at timestamptz not null default now(),
  unique (class_id, display_name)
);

create table if not exists private.teacher_credentials (
  teacher_id uuid primary key references public.teacher_profiles(id) on delete cascade,
  pin_hash text not null,
  failed_attempts integer not null default 0,
  locked_until timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists private.teacher_sessions (
  token_hash text primary key,
  teacher_id uuid not null references public.teacher_profiles(id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table if not exists public.job_worlds (
  key text primary key,
  name text not null unique,
  description text not null,
  sort_order smallint not null unique
);

create table if not exists public.jobs (
  code text primary key,
  world_key text not null references public.job_worlds(key),
  title text not null unique,
  description text not null,
  default_salary integer not null default 800 check (default_salary >= 0),
  active boolean not null default true
);

create table if not exists public.class_job_settings (
  class_id uuid not null references public.classrooms(id) on delete cascade,
  job_code text not null references public.jobs(code),
  salary integer not null check (salary >= 0),
  active boolean not null default true,
  primary key (class_id, job_code)
);

create table if not exists public.student_job_assignments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.student_profiles(id) on delete cascade,
  job_code text not null references public.jobs(code),
  assigned_at timestamptz not null default now(),
  ended_at timestamptz
);
create unique index if not exists student_job_assignments_active_idx on public.student_job_assignments(student_id) where ended_at is null;

create table if not exists public.competencies (
  key text primary key,
  name text not null unique,
  description text not null,
  color text not null,
  sort_order smallint not null unique
);

create table if not exists public.student_competencies (
  student_id uuid not null references public.student_profiles(id) on delete cascade,
  competency_key text not null references public.competencies(key),
  xp integer not null default 0 check (xp >= 0),
  updated_at timestamptz not null default now(),
  primary key (student_id, competency_key)
);

create table if not exists public.job_templates (
  id uuid primary key default gen_random_uuid(),
  title text not null unique,
  description text not null,
  world_key text not null references public.job_worlds(key),
  related_job_codes text[] not null default '{}',
  capacity smallint not null default 2 check (capacity > 0),
  reward integer not null default 200 check (reward >= 0),
  duration_minutes smallint not null default 30 check (duration_minutes > 0),
  competency_rewards jsonb not null default '{}'::jsonb,
  submission_method text not null default '활동 기록',
  repeatable boolean not null default true,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.class_weeks (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classrooms(id) on delete cascade,
  week_number integer not null check (week_number > 0),
  starts_on date not null default current_date,
  status text not null default 'active' check (status in ('active','settled','closed')),
  settled_at timestamptz,
  created_at timestamptz not null default now(),
  unique (class_id, week_number)
);
create unique index if not exists class_weeks_one_active_idx on public.class_weeks(class_id) where status='active';

create table if not exists public.job_postings (
  id uuid primary key default gen_random_uuid(),
  week_id uuid not null references public.class_weeks(id) on delete cascade,
  template_id uuid references public.job_templates(id),
  title text not null,
  description text not null,
  world_key text not null references public.job_worlds(key),
  related_job_codes text[] not null default '{}',
  capacity smallint not null check (capacity > 0),
  reward integer not null check (reward >= 0),
  duration_minutes smallint not null check (duration_minutes > 0),
  competency_rewards jsonb not null default '{}'::jsonb,
  submission_method text not null,
  status text not null default 'open' check (status in ('draft','open','closed')),
  created_at timestamptz not null default now()
);

create table if not exists public.job_applications (
  id uuid primary key default gen_random_uuid(),
  posting_id uuid not null references public.job_postings(id) on delete cascade,
  student_id uuid not null references public.student_profiles(id) on delete cascade,
  status text not null default 'assigned' check (status in ('assigned','waitlisted','submitted','completed','cancelled')),
  summary text,
  result_url text,
  fun_rating smallint check (fun_rating between 1 and 5),
  difficulty_rating smallint check (difficulty_rating between 1 and 5),
  applied_at timestamptz not null default now(),
  completed_at timestamptz,
  reward_paid boolean not null default false,
  unique (posting_id, student_id)
);

create table if not exists public.competency_events (
  id bigint generated always as identity primary key,
  student_id uuid not null references public.student_profiles(id) on delete cascade,
  competency_key text not null references public.competencies(key),
  amount integer not null check (amount > 0),
  source_type text not null,
  source_id uuid not null,
  created_at timestamptz not null default now(),
  unique (student_id, competency_key, source_type, source_id)
);

create table if not exists public.economy_transactions (
  id bigint generated always as identity primary key,
  student_id uuid not null references public.student_profiles(id) on delete cascade,
  transaction_type text not null check (transaction_type in ('salary','job_reward','rent','saving','withdrawal','donation','seat_move','adjustment')),
  cash_delta integer not null default 0,
  savings_delta integer not null default 0,
  cash_before integer not null check (cash_before >= 0),
  cash_after integer not null check (cash_after >= 0),
  savings_before integer not null check (savings_before >= 0),
  savings_after integer not null check (savings_after >= 0),
  related_type text,
  related_id text,
  approved_by text,
  status text not null default 'completed' check (status in ('completed','reversed')),
  idempotency_key text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists public.bank_requests (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.student_profiles(id) on delete cascade,
  request_type text not null check (request_type in ('saving','withdrawal')),
  amount integer not null check (amount > 0 and amount % 100 = 0),
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  reviewed_by_student_id uuid references public.student_profiles(id),
  reviewed_by_teacher_id uuid references public.teacher_profiles(id),
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz
);
create unique index if not exists bank_requests_one_pending_idx on public.bank_requests(student_id, request_type) where status='pending';

create table if not exists public.seats (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classrooms(id) on delete cascade,
  code text not null,
  name text not null,
  seat_type text not null check (seat_type in ('기본형','조용한형','창가형','협업형')),
  rent integer not null default 300 check (rent >= 0),
  move_cost integer not null default 100 check (move_cost >= 0),
  student_id uuid unique references public.student_profiles(id) on delete set null,
  active boolean not null default true,
  unique (class_id, code)
);

create table if not exists public.seat_move_requests (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.student_profiles(id) on delete cascade,
  seat_id uuid not null references public.seats(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz
);
create unique index if not exists seat_move_one_pending_student_idx on public.seat_move_requests(student_id) where status='pending';

create table if not exists public.community_goals (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classrooms(id) on delete cascade,
  title text not null,
  description text not null,
  target_amount integer not null check (target_amount > 0),
  min_donations_per_student integer not null default 2 check (min_donations_per_student > 0),
  status text not null default 'active' check (status in ('active','achieved','closed')),
  achieved_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index if not exists community_goals_one_active_idx on public.community_goals(class_id) where status='active';

create table if not exists public.donations (
  id uuid primary key default gen_random_uuid(),
  goal_id uuid not null references public.community_goals(id) on delete cascade,
  student_id uuid not null references public.student_profiles(id) on delete cascade,
  amount integer not null check (amount > 0),
  transaction_id bigint unique references public.economy_transactions(id),
  created_at timestamptz not null default now()
);

create table if not exists public.badges (
  key text primary key,
  name text not null unique,
  description text not null,
  icon text not null
);
create table if not exists public.student_badges (
  student_id uuid not null references public.student_profiles(id) on delete cascade,
  badge_key text not null references public.badges(key),
  awarded_at timestamptz not null default now(),
  reason text not null,
  primary key (student_id, badge_key)
);

create table if not exists public.room_items (
  key text primary key,
  name text not null,
  slot text not null check (slot in ('wall','floor','desk','chair','large','decor','badge')),
  style text not null check (style in ('기본형','자연형','독서형','디지털형','예술형','메이커형')),
  savings_required integer not null default 0 check (savings_required >= 0),
  visual text not null,
  sort_order smallint not null
);
create table if not exists public.student_room (
  student_id uuid not null references public.student_profiles(id) on delete cascade,
  slot text not null,
  item_key text not null references public.room_items(key),
  equipped_at timestamptz not null default now(),
  primary key (student_id, slot)
);

create table if not exists public.exception_flags (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classrooms(id) on delete cascade,
  student_id uuid references public.student_profiles(id) on delete cascade,
  flag_type text not null,
  title text not null,
  detail text not null,
  status text not null default 'open' check (status in ('open','resolved')),
  source_key text not null unique,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index if not exists teacher_profiles_class_idx on public.teacher_profiles(class_id);
create index if not exists teacher_sessions_teacher_idx on private.teacher_sessions(teacher_id);
create index if not exists teacher_sessions_expiry_idx on private.teacher_sessions(expires_at);
create index if not exists class_job_settings_job_idx on public.class_job_settings(job_code);
create index if not exists student_job_assignments_job_idx on public.student_job_assignments(job_code);
create index if not exists student_competencies_key_idx on public.student_competencies(competency_key);
create index if not exists job_templates_world_idx on public.job_templates(world_key);
create index if not exists class_weeks_class_status_idx on public.class_weeks(class_id,status);
create index if not exists job_postings_week_status_idx on public.job_postings(week_id,status);
create index if not exists job_applications_student_status_idx on public.job_applications(student_id,status);
create index if not exists job_applications_posting_status_idx on public.job_applications(posting_id,status);
create index if not exists competency_events_student_created_idx on public.competency_events(student_id,created_at desc);
create index if not exists economy_transactions_student_created_idx on public.economy_transactions(student_id,created_at desc);
create index if not exists bank_requests_status_created_idx on public.bank_requests(status,requested_at);
create index if not exists bank_requests_reviewer_student_idx on public.bank_requests(reviewed_by_student_id);
create index if not exists bank_requests_reviewer_teacher_idx on public.bank_requests(reviewed_by_teacher_id);
create index if not exists seats_class_available_idx on public.seats(class_id,student_id) where active;
create index if not exists seat_move_requests_seat_status_idx on public.seat_move_requests(seat_id,status);
create index if not exists donations_goal_student_idx on public.donations(goal_id,student_id);
create index if not exists student_badges_badge_idx on public.student_badges(badge_key);
create index if not exists room_items_slot_savings_idx on public.room_items(slot,savings_required);
create index if not exists exception_flags_class_status_idx on public.exception_flags(class_id,status,created_at desc);
create index if not exists competency_events_key_idx on public.competency_events(competency_key);
create index if not exists donations_student_idx on public.donations(student_id);
create index if not exists exception_flags_student_idx on public.exception_flags(student_id);
create index if not exists job_postings_template_idx on public.job_postings(template_id);
create index if not exists job_postings_world_idx on public.job_postings(world_key);
create index if not exists jobs_world_idx on public.jobs(world_key);
create index if not exists student_room_item_idx on public.student_room(item_key);

insert into public.job_worlds(key,name,description,sort_order) values
('help','사람을 돕는 일','배움과 마음을 살피며 서로의 성장을 돕는 세계',1),
('make','만들고 해결하는 일','아이디어를 만들고 불편을 해결하는 세계',2),
('info','정보와 돈을 다루는 일','정보와 경제 흐름을 정확히 다루는 세계',3),
('express','알리고 표현하는 일','생각과 소식을 매력적으로 전하는 세계',4),
('organize','조직하고 운영하는 일','사람과 일정을 연결해 함께 움직이는 세계',5),
('space','환경과 공간을 관리하는 일','모두가 지내는 공간을 안전하고 쾌적하게 만드는 세계',6)
on conflict (key) do update set name=excluded.name,description=excluded.description,sort_order=excluded.sort_order;

insert into public.jobs(code,world_key,title,description,default_salary) values
('banker','info','은행원','저축과 출금 요청을 확인하고 건강한 금융생활을 돕습니다.',800),
('teacher','help','교사','친구의 배움을 돕고 학습자료를 정리합니다.',800),
('counselor','help','상담사','학급 의견을 경청하고 더 나은 생활 아이디어를 모읍니다.',800),
('maker','make','목공·제작자','교실과 행사에 필요한 물품을 직접 만듭니다.',820),
('engineer','make','엔지니어','교실의 불편을 발견하고 해결안을 시험합니다.',820),
('reporter','express','기자','학급 소식을 취재하고 알기 쉽게 전합니다.',800),
('designer','express','디자이너','안내물과 게시물을 보기 좋게 표현합니다.',800),
('analyst','info','데이터분석가','설문과 투표 결과를 정리해 의미를 찾습니다.',810),
('planner','organize','행사기획자','행사의 역할·준비물·일정을 계획합니다.',810),
('hr','organize','인사담당자','공고와 참여 기록을 정리해 일이 잘 이어지게 돕습니다.',800),
('environment','space','환경관리사','교실 환경을 살피고 개선 아이디어를 실천합니다.',800),
('facility','space','시설관리자','교실 물품을 점검하고 수리할 일을 연결합니다.',810)
on conflict (code) do update set world_key=excluded.world_key,title=excluded.title,description=excluded.description,default_salary=excluded.default_salary;

insert into public.competencies(key,name,description,color,sort_order) values
('self_management','자기관리 역량','자아정체성과 자신감을 바탕으로 삶과 진로를 스스로 설계하고 자기주도적으로 살아가는 힘','#d75d88',1),
('knowledge_information','지식정보처리 역량','다양한 지식과 정보를 깊이 이해하고 비판적으로 탐구해 문제 해결에 활용하는 힘','#8b6cc7',2),
('creative_thinking','창의적 사고 역량','지식·기술·경험을 융합해 새로운 것을 만들어 내는 힘','#f08a4b',3),
('aesthetic_emotion','심미적 감성 역량','공감과 문화적 감수성으로 삶의 의미와 가치를 성찰하고 향유하는 힘','#e06f8f',4),
('collaborative_communication','협력적 소통 역량','다른 관점을 존중하고 경청하며 생각과 감정을 표현해 공동 목적을 이루는 힘','#2a9d75',5),
('community','공동체 역량','개방적·포용적 태도로 지속 가능한 공동체 발전에 책임감 있게 참여하는 힘','#3f7bd9',6)
on conflict (key) do update set name=excluded.name,description=excluded.description,color=excluded.color,sort_order=excluded.sort_order;

insert into public.badges(key,name,description,icon) values
('first_job','첫 직업 경험','첫 공고 업무를 완료했어요.','🚀'),('finance','금융 경험','저축 또는 출금 과정을 경험했어요.','🏦'),
('design','디자인 경험','표현 분야 업무를 두 번 완료했어요.','🎨'),('communication','소통 경험','협력적 소통 역량을 10 이상 사용했어요.','🎙️'),
('maker','제작 경험','만들고 해결하는 업무를 완료했어요.','🛠️'),('explorer','탐험가','서로 다른 세 직업 세계를 경험했어요.','🧭'),
('saving','저축 목표','저축 3,000꿈을 달성했어요.','🌱'),('community','공동체 기여','공동체기금에 두 번 이상 참여했어요.','🤝')
on conflict (key) do update set name=excluded.name,description=excluded.description,icon=excluded.icon;

insert into public.room_items(key,name,slot,style,savings_required,visual,sort_order) values
('wall_basic','밝은 벽지','wall','기본형',0,'▫️',1),('wall_nature','숲빛 벽지','wall','자연형',5000,'🌿',2),
('floor_basic','포근한 바닥','floor','기본형',0,'🟫',3),('desk_basic','나의 책상','desk','기본형',0,'🪑',4),
('chair_reading','독서 의자','chair','독서형',2000,'📖',5),('plant','초록 화분','decor','자연형',1000,'🪴',6),
('rug','포근한 러그','decor','예술형',2000,'🟣',7),('bookshelf','원목 책장','large','독서형',3000,'📚',8),
('digital_desk','디지털 작업대','desk','디지털형',3000,'💻',9),('maker_shelf','메이커 공구함','large','메이커형',3000,'🧰',10)
on conflict (key) do update set name=excluded.name,slot=excluded.slot,style=excluded.style,savings_required=excluded.savings_required,visual=excluded.visual,sort_order=excluded.sort_order;

insert into public.job_templates(title,description,world_key,related_job_codes,capacity,reward,duration_minutes,competency_rewards,submission_method,repeatable) values
('학급신문 만들기','이번 주 학급 소식을 모아 한 장의 신문으로 정리해요.','express',array['reporter','designer'],3,300,40,'{"knowledge_information":2,"creative_thinking":2,"collaborative_communication":2}','글 또는 사진',true),
('친구 인터뷰','친구의 관심사와 생각을 경청하고 핵심 내용을 기록해요.','express',array['reporter','counselor'],2,250,30,'{"knowledge_information":1,"collaborative_communication":3,"aesthetic_emotion":1}','인터뷰 기록',true),
('행사 포스터 만들기','학급 행사를 한눈에 알 수 있는 포스터를 만들어요.','express',array['designer','reporter'],2,300,40,'{"creative_thinking":3,"aesthetic_emotion":3,"collaborative_communication":1}','결과물 또는 사진',true),
('학급문고 개선','책을 더 쉽게 찾고 정리할 수 있는 방법을 제안해요.','make',array['maker','engineer'],2,280,35,'{"knowledge_information":2,"creative_thinking":2,"community":2}','개선안과 사진',true),
('수납방법 개선','교실 물품의 위치와 사용 흐름을 살펴 새 수납 방식을 시험해요.','make',array['maker','engineer'],2,280,35,'{"self_management":1,"creative_thinking":3,"community":2}','개선 전후 기록',true),
('교실 불편사항 조사','교실에서 불편한 점을 찾고 해결 우선순위를 정해요.','make',array['engineer','facility'],3,260,30,'{"knowledge_information":2,"creative_thinking":2,"community":2}','조사표',true),
('학급 설문 분석','설문 결과를 표와 그래프로 정리하고 의미를 설명해요.','info',array['analyst'],3,250,30,'{"knowledge_information":3,"creative_thinking":1,"collaborative_communication":1}','표 또는 그래프',true),
('행사 준비','행사 역할·준비물·시간표를 정하고 친구들과 준비해요.','organize',array['planner','hr'],4,300,45,'{"self_management":2,"collaborative_communication":2,"community":2}','계획표와 활동 기록',true),
('교실 물품 점검','책상·의자·공용 물품을 점검하고 수리가 필요한 일을 등록해요.','space',array['facility','environment'],3,230,25,'{"self_management":2,"knowledge_information":1,"community":3}','점검표',true),
('학급 안내판 제작','중요한 일정과 소식을 보기 쉽게 정리한 안내판을 만들어요.','express',array['designer','reporter'],2,270,35,'{"creative_thinking":2,"aesthetic_emotion":2,"community":2}','결과물 사진',true),
('복습 퀴즈 만들기','친구들이 배운 내용을 되짚을 수 있는 퀴즈를 만들어요.','help',array['teacher'],2,240,30,'{"knowledge_information":3,"creative_thinking":1,"collaborative_communication":2}','퀴즈 문항',true),
('학급 만족도 조사','모두가 편안한 학급을 위해 의견을 듣고 개선 아이디어를 정리해요.','help',array['counselor','analyst'],3,260,35,'{"aesthetic_emotion":2,"collaborative_communication":2,"community":2}','조사 결과',true)
on conflict (title) do update set description=excluded.description,world_key=excluded.world_key,related_job_codes=excluded.related_job_codes,capacity=excluded.capacity,reward=excluded.reward,duration_minutes=excluded.duration_minutes,competency_rewards=excluded.competency_rewards,submission_method=excluded.submission_method;

insert into public.student_competencies(student_id,competency_key)
select s.id,c.key from public.student_profiles s cross join public.competencies c on conflict do nothing;
insert into public.student_job_assignments(student_id,job_code)
select s.id,j.code from public.student_profiles s join public.jobs j on j.title=s.basic_job
where not exists (select 1 from public.student_job_assignments a where a.student_id=s.id and a.ended_at is null);
insert into public.class_job_settings(class_id,job_code,salary)
select c.id,j.code,j.default_salary from public.classrooms c cross join public.jobs j on conflict do nothing;

insert into public.seats(class_id,code,name,seat_type,rent,move_cost,student_id)
select c.id,v.code,v.name,v.seat_type,v.rent,v.move_cost,null
from public.classrooms c cross join (values
('A-1','햇살 A-1','창가형',320,100),('A-2','햇살 A-2','창가형',320,100),('B-1','집중 B-1','조용한형',300,100),
('B-2','집중 B-2','조용한형',300,100),('C-1','함께 C-1','협업형',300,100),('C-2','함께 C-2','협업형',300,100),
('D-1','든든 D-1','기본형',280,100),('D-2','든든 D-2','기본형',280,100)
) as v(code,name,seat_type,rent,move_cost)
on conflict (class_id,code) do nothing;

insert into public.community_goals(class_id,title,description,target_amount,min_donations_per_student)
select c.id,'피구놀이','모두가 두 번 이상 참여하고 10,000꿈을 모으면 피구놀이가 열려요.',10000,2
from public.classrooms c where not exists(select 1 from public.community_goals g where g.class_id=c.id and g.status='active');

with ranked_students as (
  select s.id,s.class_id,row_number() over(partition by s.class_id order by s.student_number) as rn
  from public.student_profiles s where not exists(select 1 from public.seats x where x.student_id=s.id)
), ranked_seats as (
  select x.id,x.class_id,row_number() over(partition by x.class_id order by x.code) as rn
  from public.seats x where x.student_id is null
)
update public.seats x set student_id=rs.id
from ranked_seats rx join ranked_students rs on rs.class_id=rx.class_id and rs.rn=rx.rn
where x.id=rx.id;

insert into public.class_weeks(class_id,week_number,starts_on)
select c.id,1,current_date from public.classrooms c
where not exists(select 1 from public.class_weeks w where w.class_id=c.id)
on conflict do nothing;
insert into public.job_postings(week_id,template_id,title,description,world_key,related_job_codes,capacity,reward,duration_minutes,competency_rewards,submission_method)
select w.id,t.id,t.title,t.description,t.world_key,t.related_job_codes,t.capacity,t.reward,t.duration_minutes,t.competency_rewards,t.submission_method
from public.class_weeks w cross join lateral (select * from public.job_templates where active order by created_at,title limit 4) t
where w.status='active' and not exists(select 1 from public.job_postings p where p.week_id=w.id);

do $$ declare t text; begin
  foreach t in array array['teacher_profiles','job_worlds','jobs','class_job_settings','student_job_assignments','competencies','student_competencies','job_templates','class_weeks','job_postings','job_applications','competency_events','economy_transactions','bank_requests','seats','seat_move_requests','community_goals','donations','badges','student_badges','room_items','student_room','exception_flags'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('alter table public.%I force row level security',t);
    if not exists(select 1 from pg_policies where schemaname='public' and tablename=t and policyname=t||'_deny_direct_access') then
      execute format('create policy %I on public.%I for all to anon, authenticated using(false) with check(false)',t||'_deny_direct_access',t);
    end if;
    execute format('revoke all on public.%I from anon, authenticated',t);
  end loop;
end $$;

create or replace function private.teacher_from_session(p_token text) returns uuid language sql security definer set search_path='' as $$
  select teacher_id from private.teacher_sessions where token_hash=encode(extensions.digest(p_token,'sha256'),'hex') and expires_at>now() limit 1
$$;

create or replace function private.apply_transaction(p_sid uuid,p_type text,p_cash integer,p_savings integer,p_key text,p_related_type text default null,p_related_id text default null,p_approved_by text default null)
returns bigint language plpgsql security definer set search_path='' as $$
declare s record; tx bigint;
begin
  select cash,savings into s from public.student_profiles where id=p_sid for update;
  if s is null then raise exception 'student_not_found'; end if;
  if s.cash+p_cash<0 then raise exception 'insufficient_cash'; end if;
  if s.savings+p_savings<0 then raise exception 'insufficient_savings'; end if;
  insert into public.economy_transactions(student_id,transaction_type,cash_delta,savings_delta,cash_before,cash_after,savings_before,savings_after,related_type,related_id,approved_by,idempotency_key)
  values(p_sid,p_type,p_cash,p_savings,s.cash,s.cash+p_cash,s.savings,s.savings+p_savings,p_related_type,p_related_id,p_approved_by,p_key)
  on conflict(idempotency_key) do nothing returning id into tx;
  if tx is null then select id into tx from public.economy_transactions where idempotency_key=p_key; return tx; end if;
  update public.student_profiles set cash=s.cash+p_cash,savings=s.savings+p_savings,updated_at=now() where id=p_sid;
  return tx;
end $$;

create or replace function private.refresh_student_rewards(p_sid uuid) returns void language plpgsql security definer set search_path='' as $$
declare saved integer; completed integer; worlds integer; comm_xp integer;
begin
  select savings into saved from public.student_profiles where id=p_sid;
  select count(*) into completed from public.job_applications where student_id=p_sid and status='completed';
  select count(distinct p.world_key) into worlds from public.job_applications a join public.job_postings p on p.id=a.posting_id where a.student_id=p_sid and a.status='completed';
  select coalesce(xp,0) into comm_xp from public.student_competencies where student_id=p_sid and competency_key='collaborative_communication';
  if completed>=1 then insert into public.student_badges values(p_sid,'first_job',now(),'첫 공고 완료') on conflict do nothing; end if;
  if completed>=1 then perform private.unlock_feature(p_sid,'badges','첫 공고 완료'); end if;
  if worlds>=3 then insert into public.student_badges values(p_sid,'explorer',now(),'서로 다른 세 직업 세계 경험') on conflict do nothing; end if;
  if saved>=3000 then
    insert into public.student_badges values(p_sid,'saving',now(),'저축 3,000꿈 달성') on conflict do nothing;
    perform private.unlock_feature(p_sid,'my_room','저축 3,000꿈');
  end if;
  if (select donation_count from public.student_progress where student_id=p_sid)>=2 then insert into public.student_badges values(p_sid,'community',now(),'공동체기금 2회 참여') on conflict do nothing; end if;
  if comm_xp>=10 then insert into public.student_badges values(p_sid,'communication',now(),'협력적 소통 역량 10 달성') on conflict do nothing; end if;
  update public.student_progress set jobs_completed=completed,unique_job_categories_experienced=worlds,growth_stage=greatest(growth_stage,least(6,2+worlds)),updated_at=now() where student_id=p_sid;
end $$;

create or replace function public.fo_complete_basic_task(p_session_token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare sid uuid:=private.session_student(p_session_token); n integer; paid boolean;
begin
 if sid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 select basic_job_tasks_completed,first_salary_received into n,paid from public.student_progress where student_id=sid for update;
 update public.student_progress set basic_job_tasks_completed=n+1,first_salary_received=true,growth_stage=greatest(growth_stage,case when n+1>=2 then 3 else 2 end),updated_at=now() where student_id=sid;
 if not paid then
   perform private.apply_transaction(sid,'salary',800,0,'first_salary:'||sid,'basic_task',sid::text,'system');
   perform private.unlock_feature(sid,'wallet','첫 월급'); perform private.unlock_feature(sid,'bank','첫 월급'); perform private.unlock_feature(sid,'community_fund','첫 월급');
 end if;
 if n+1>=2 then perform private.unlock_feature(sid,'job_board','기본업무 2회'); end if;
 if n+1>=4 then perform private.unlock_feature(sid,'competencies','업무 경험 4회'); end if;
 return jsonb_build_object('ok',true,'student',private.student_context(sid));
end $$;

create or replace function private.student_context(p_student_id uuid) returns jsonb language sql security definer set search_path='' as $$
select jsonb_build_object(
 'student_id',s.id,'display_name',s.display_name,'student_number',s.student_number,'first_login',s.first_login,'account_status',s.account_status,
 'basic_job',coalesce(j.title,s.basic_job),'job_world',w.name,'cash',s.cash,'savings',s.savings,'housing_name',coalesce(seat.name,s.housing_name),
 'growth_stage',p.growth_stage,'basic_job_tasks_completed',p.basic_job_tasks_completed,'jobs_completed',p.jobs_completed,
 'first_salary_received',p.first_salary_received,'first_saving_completed',p.first_saving_completed,'saving_goal_reached',p.saving_goal_reached,
 'donation_count',p.donation_count,'total_donation',p.total_donation,
 'feature_unlocks',coalesce((select jsonb_agg(feature_key order by unlocked_at) from public.feature_unlocks where student_id=s.id),'[]'::jsonb),
 'competencies',coalesce((select jsonb_agg(jsonb_build_object('key',c.key,'name',c.name,'xp',coalesce(sc.xp,0),'color',c.color) order by c.sort_order) from public.competencies c left join public.student_competencies sc on sc.competency_key=c.key and sc.student_id=s.id),'[]'::jsonb),
 'postings',coalesce((select jsonb_agg(jsonb_build_object('id',jp.id,'title',jp.title,'description',jp.description,'world',jw.name,'capacity',jp.capacity,'reward',jp.reward,'duration_minutes',jp.duration_minutes,'competency_rewards',jp.competency_rewards,'submission_method',jp.submission_method,'status',jp.status,'assigned_count',(select count(*) from public.job_applications a where a.posting_id=jp.id and a.status in ('assigned','submitted','completed'))) order by jp.created_at) from public.job_postings jp join public.class_weeks cw on cw.id=jp.week_id join public.job_worlds jw on jw.key=jp.world_key where cw.class_id=s.class_id and cw.status='active' and jp.status='open'),'[]'::jsonb),
 'applications',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'posting_id',a.posting_id,'title',jp.title,'status',a.status,'summary',a.summary,'fun_rating',a.fun_rating,'difficulty_rating',a.difficulty_rating,'completed_at',a.completed_at) order by a.applied_at desc) from public.job_applications a join public.job_postings jp on jp.id=a.posting_id where a.student_id=s.id),'[]'::jsonb),
 'transactions',coalesce((select jsonb_agg(x order by x.created_at desc) from (select id,transaction_type,cash_delta,savings_delta,cash_after,savings_after,created_at from public.economy_transactions where student_id=s.id order by created_at desc limit 12)x),'[]'::jsonb),
 'bank_requests',coalesce((select jsonb_agg(x order by x.requested_at desc) from (select id,request_type,amount,status,requested_at from public.bank_requests where student_id=s.id order by requested_at desc limit 8)x),'[]'::jsonb),
 'bank_queue',case when coalesce(j.code,'')='banker' then coalesce((select jsonb_agg(jsonb_build_object('id',br.id,'student_name',sp.display_name,'request_type',br.request_type,'amount',br.amount,'requested_at',br.requested_at) order by br.requested_at) from public.bank_requests br join public.student_profiles sp on sp.id=br.student_id where sp.class_id=s.class_id and br.status='pending' and br.student_id<>s.id),'[]'::jsonb) else '[]'::jsonb end,
 'badges',coalesce((select jsonb_agg(jsonb_build_object('key',b.key,'name',b.name,'description',b.description,'icon',b.icon,'awarded_at',sb.awarded_at) order by sb.awarded_at) from public.student_badges sb join public.badges b on b.key=sb.badge_key where sb.student_id=s.id),'[]'::jsonb),
 'room_items',coalesce((select jsonb_agg(jsonb_build_object('key',ri.key,'name',ri.name,'slot',ri.slot,'style',ri.style,'required',ri.savings_required,'visual',ri.visual,'unlocked',s.savings>=ri.savings_required,'equipped',sr.item_key=ri.key) order by ri.sort_order) from public.room_items ri left join public.student_room sr on sr.student_id=s.id and sr.slot=ri.slot),'[]'::jsonb),
 'seats',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'code',x.code,'name',x.name,'type',x.seat_type,'rent',x.rent,'move_cost',x.move_cost,'available',x.student_id is null) order by x.code) from public.seats x where x.class_id=s.class_id and x.active),'[]'::jsonb),
 'community_goal',coalesce((select jsonb_build_object('id',g.id,'title',g.title,'description',g.description,'target_amount',g.target_amount,'current_amount',coalesce(sum(d.amount),0),'min_donations',g.min_donations_per_student,'qualified_students',(select count(*) from (select student_id from public.donations where goal_id=g.id group by student_id having count(*)>=g.min_donations_per_student)q),'total_students',(select count(*) from public.student_profiles where class_id=s.class_id and account_status='active'),'status',g.status) from public.community_goals g left join public.donations d on d.goal_id=g.id where g.class_id=s.class_id and g.status in ('active','achieved') group by g.id order by g.created_at desc limit 1),'{}'::jsonb)
)
from public.student_profiles s
join public.student_progress p on p.student_id=s.id
left join public.student_job_assignments a on a.student_id=s.id and a.ended_at is null
left join public.jobs j on j.code=a.job_code
left join public.job_worlds w on w.key=j.world_key
left join public.seats seat on seat.student_id=s.id
where s.id=p_student_id
$$;

create or replace function private.teacher_context(tid uuid) returns jsonb language sql security definer set search_path='' as $$
select jsonb_build_object(
 'teacher_id',t.id,'display_name',t.display_name,'class_id',c.id,'class_code',c.class_code,'class_name',c.name,
 'active_week',coalesce((select jsonb_build_object('id',w.id,'week_number',w.week_number,'starts_on',w.starts_on,'status',w.status) from public.class_weeks w where w.class_id=c.id order by w.week_number desc limit 1),'{}'::jsonb),
 'stats',jsonb_build_object('students',(select count(*) from public.student_profiles where class_id=c.id and account_status='active'),'participating',(select count(distinct a.student_id) from public.job_applications a join public.job_postings p on p.id=a.posting_id join public.class_weeks w on w.id=p.week_id where w.class_id=c.id and w.status='active'),'completed',(select count(*) from public.job_applications a join public.job_postings p on p.id=a.posting_id join public.class_weeks w on w.id=p.week_id where w.class_id=c.id and w.status='active' and a.status='completed'),'exceptions',(select count(*) from public.exception_flags where class_id=c.id and status='open')),
 'students',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.display_name,'number',s.student_number,'job',s.basic_job,'cash',s.cash,'savings',s.savings,'tasks',p.basic_job_tasks_completed,'jobs_completed',p.jobs_completed) order by s.student_number) from public.student_profiles s join public.student_progress p on p.student_id=s.id where s.class_id=c.id),'[]'::jsonb),
 'postings',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'title',p.title,'capacity',p.capacity,'assigned',(select count(*) from public.job_applications a where a.posting_id=p.id and a.status in ('assigned','submitted','completed')),'completed',(select count(*) from public.job_applications a where a.posting_id=p.id and a.status='completed'),'status',p.status) order by p.created_at) from public.job_postings p join public.class_weeks w on w.id=p.week_id where w.class_id=c.id and w.status='active'),'[]'::jsonb),
 'bank_requests',coalesce((select jsonb_agg(jsonb_build_object('id',br.id,'student_name',s.display_name,'request_type',br.request_type,'amount',br.amount,'status',br.status) order by br.requested_at) from public.bank_requests br join public.student_profiles s on s.id=br.student_id where s.class_id=c.id and br.status='pending'),'[]'::jsonb),
 'exceptions',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'type',e.flag_type,'title',e.title,'detail',e.detail,'student_name',s.display_name,'created_at',e.created_at) order by e.created_at desc) from public.exception_flags e left join public.student_profiles s on s.id=e.student_id where e.class_id=c.id and e.status='open'),'[]'::jsonb),
 'community_goal',coalesce((select jsonb_build_object('id',g.id,'title',g.title,'target_amount',g.target_amount,'current_amount',coalesce(sum(d.amount),0),'status',g.status) from public.community_goals g left join public.donations d on d.goal_id=g.id where g.class_id=c.id and g.status in ('active','achieved') group by g.id order by g.created_at desc limit 1),'{}'::jsonb)
)
from public.teacher_profiles t join public.classrooms c on c.id=t.class_id where t.id=tid
$$;

create or replace function public.fo_student_apply(p_session_token text,p_posting_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare sid uuid:=private.session_student(p_session_token); post record; assigned_count integer; app_status text; result_message text;
begin
 if sid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 select p.* into post from public.job_postings p join public.class_weeks w on w.id=p.week_id join public.student_profiles s on s.class_id=w.class_id where p.id=p_posting_id and s.id=sid and p.status='open' and w.status='active' for update of p;
 if post is null then return jsonb_build_object('ok',false,'message','현재 지원할 수 없는 공고예요.'); end if;
 select count(*) into assigned_count from public.job_applications where posting_id=p_posting_id and status in ('assigned','submitted','completed');
 app_status:=case when assigned_count<post.capacity then 'assigned' else 'waitlisted' end;
 result_message:=case when app_status='assigned' then '참여가 확정됐어요.' else '대기 명단에 등록됐어요.' end;
 insert into public.job_applications(posting_id,student_id,status) values(p_posting_id,sid,app_status) on conflict(posting_id,student_id) do nothing;
 return jsonb_build_object('ok',true,'message',result_message,'student',private.student_context(sid));
end $$;

create or replace function public.fo_student_complete_job(p_session_token text,p_application_id uuid,p_summary text,p_result_url text,p_fun integer,p_difficulty integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare sid uuid:=private.session_student(p_session_token); app record; kv record;
begin
 if sid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 if length(trim(coalesce(p_summary,'')))<5 or p_fun not between 1 and 5 or p_difficulty not between 1 and 5 then return jsonb_build_object('ok',false,'message','한 일과 느낌을 조금 더 기록해 주세요.'); end if;
 select a.*,p.reward,p.competency_rewards,p.world_key into app from public.job_applications a join public.job_postings p on p.id=a.posting_id where a.id=p_application_id and a.student_id=sid for update of a;
 if app is null or app.status not in ('assigned','submitted') then return jsonb_build_object('ok',false,'message','완료할 수 없는 업무예요.'); end if;
 update public.job_applications set status='completed',summary=trim(p_summary),result_url=nullif(trim(coalesce(p_result_url,'')),''),fun_rating=p_fun,difficulty_rating=p_difficulty,completed_at=now(),reward_paid=true where id=app.id;
 perform private.apply_transaction(sid,'job_reward',app.reward,0,'job_reward:'||app.id,'job_application',app.id::text,'system');
 for kv in select key,value from jsonb_each_text(app.competency_rewards) loop
   insert into public.competency_events(student_id,competency_key,amount,source_type,source_id) values(sid,kv.key,kv.value::integer,'job_application',app.id) on conflict do nothing;
   if found then insert into public.student_competencies(student_id,competency_key,xp) values(sid,kv.key,kv.value::integer) on conflict(student_id,competency_key) do update set xp=public.student_competencies.xp+excluded.xp,updated_at=now(); end if;
 end loop;
 if app.world_key='make' then insert into public.student_badges values(sid,'maker',now(),'만들고 해결하는 업무 완료') on conflict do nothing; end if;
 if app.world_key='express' and (select count(*) from public.job_applications a join public.job_postings p on p.id=a.posting_id where a.student_id=sid and a.status='completed' and p.world_key='express')>=2 then insert into public.student_badges values(sid,'design',now(),'표현 분야 업무 2회 완료') on conflict do nothing; end if;
 perform private.refresh_student_rewards(sid);
 return jsonb_build_object('ok',true,'message','업무 기록과 보상, 핵심역량이 반영됐어요.','student',private.student_context(sid));
end $$;

create or replace function public.fo_student_bank_request(p_session_token text,p_type text,p_amount integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare sid uuid:=private.session_student(p_session_token); s record;
begin
 if sid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 if p_type not in ('saving','withdrawal') or p_amount<100 or p_amount>5000 or p_amount%100<>0 then return jsonb_build_object('ok',false,'message','100꿈 단위로 100~5,000꿈을 신청해 주세요.'); end if;
 select cash,savings into s from public.student_profiles where id=sid;
 if (p_type='saving' and s.cash<p_amount) or (p_type='withdrawal' and s.savings<p_amount) then return jsonb_build_object('ok',false,'message','신청할 수 있는 잔액이 부족해요.'); end if;
 insert into public.bank_requests(student_id,request_type,amount) values(sid,p_type,p_amount);
 return jsonb_build_object('ok',true,'message','은행원 확인을 기다리고 있어요.','student',private.student_context(sid));
exception when unique_violation then return jsonb_build_object('ok',false,'message','이미 확인을 기다리는 같은 종류의 신청이 있어요.');
end $$;

create or replace function public.fo_student_review_bank(p_session_token text,p_request_id uuid,p_decision text) returns jsonb language plpgsql security definer set search_path='' as $$
declare reviewer uuid:=private.session_student(p_session_token); req record; reviewer_job text; cash_change integer; savings_change integer;
begin
 if reviewer is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 select j.code into reviewer_job from public.student_job_assignments a join public.jobs j on j.code=a.job_code where a.student_id=reviewer and a.ended_at is null;
 if reviewer_job<>'banker' then return jsonb_build_object('ok',false,'message','은행원만 확인할 수 있어요.'); end if;
 select br.* into req from public.bank_requests br join public.student_profiles owner on owner.id=br.student_id join public.student_profiles rv on rv.id=reviewer and rv.class_id=owner.class_id where br.id=p_request_id and br.status='pending' and br.student_id<>reviewer for update of br;
 if req is null then return jsonb_build_object('ok',false,'message','이미 처리됐거나 확인할 수 없는 신청이에요.'); end if;
 if p_decision='reject' then update public.bank_requests set status='rejected',reviewed_by_student_id=reviewer,reviewed_at=now() where id=req.id;
 elsif p_decision='approve' then
   cash_change:=case when req.request_type='saving' then -req.amount else req.amount end;
   savings_change:=-cash_change;
   begin perform private.apply_transaction(req.student_id,req.request_type,cash_change,savings_change,'bank_request:'||req.id,'bank_request',req.id::text,reviewer::text);
   exception when others then return jsonb_build_object('ok',false,'message','신청 학생의 잔액이 달라져 처리하지 못했어요.'); end;
   update public.bank_requests set status='approved',reviewed_by_student_id=reviewer,reviewed_at=now() where id=req.id;
   update public.student_progress set first_saving_completed=first_saving_completed or req.request_type='saving',saving_goal_reached=saving_goal_reached or (select savings>=3000 from public.student_profiles where id=req.student_id),updated_at=now() where student_id=req.student_id;
   if req.request_type='saving' then perform private.unlock_feature(req.student_id,'housing','첫 저축'); insert into public.student_badges values(req.student_id,'finance',now(),'은행 거래 완료') on conflict do nothing; end if;
   perform private.refresh_student_rewards(req.student_id);
 else return jsonb_build_object('ok',false,'message','승인 또는 반려를 선택해 주세요.'); end if;
 return jsonb_build_object('ok',true,'message','은행 신청을 처리했어요.','student',private.student_context(reviewer));
end $$;

create or replace function public.fo_student_donate(p_session_token text,p_goal_id uuid,p_amount integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare sid uuid:=private.session_student(p_session_token); tx bigint; class_match boolean;
begin
 if sid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 if p_amount<100 or p_amount>1000 or p_amount%100<>0 then return jsonb_build_object('ok',false,'message','100꿈 단위로 기부해 주세요.'); end if;
 select exists(select 1 from public.community_goals g join public.student_profiles s on s.class_id=g.class_id where g.id=p_goal_id and g.status='active' and s.id=sid) into class_match;
 if not class_match then return jsonb_build_object('ok',false,'message','현재 참여할 수 없는 목표예요.'); end if;
 begin tx:=private.apply_transaction(sid,'donation',-p_amount,0,'donation:'||gen_random_uuid(),'community_goal',p_goal_id::text,'student'); exception when others then return jsonb_build_object('ok',false,'message','현금이 부족해요.'); end;
 insert into public.donations(goal_id,student_id,amount,transaction_id) values(p_goal_id,sid,p_amount,tx);
 update public.student_progress set donation_count=donation_count+1,total_donation=total_donation+p_amount,updated_at=now() where student_id=sid;
 update public.community_goals g set status='achieved',achieved_at=now() where g.id=p_goal_id and (select coalesce(sum(amount),0) from public.donations where goal_id=g.id)>=g.target_amount and not exists(select 1 from public.student_profiles s where s.class_id=g.class_id and s.account_status='active' and (select count(*) from public.donations d where d.goal_id=g.id and d.student_id=s.id)<g.min_donations_per_student);
 perform private.refresh_student_rewards(sid);
 return jsonb_build_object('ok',true,'message','공동체 목표에 마음을 보탰어요.','student',private.student_context(sid));
end $$;

create or replace function public.fo_student_equip_room(p_session_token text,p_item_key text) returns jsonb language plpgsql security definer set search_path='' as $$
declare sid uuid:=private.session_student(p_session_token); item record; saved integer;
begin
 if sid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 select savings into saved from public.student_profiles where id=sid;
 select * into item from public.room_items where key=p_item_key and savings_required<=saved;
 if item is null then return jsonb_build_object('ok',false,'message','아직 해금되지 않은 아이템이에요.'); end if;
 insert into public.student_room(student_id,slot,item_key) values(sid,item.slot,item.key) on conflict(student_id,slot) do update set item_key=excluded.item_key,equipped_at=now();
 return jsonb_build_object('ok',true,'message',item.name||'을(를) 방에 놓았어요.','student',private.student_context(sid));
end $$;

create or replace function public.fo_student_request_seat(p_session_token text,p_seat_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare sid uuid:=private.session_student(p_session_token); ok boolean;
begin
 if sid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 select exists(select 1 from public.seats seat join public.student_profiles s on s.class_id=seat.class_id where seat.id=p_seat_id and seat.student_id is null and seat.active and s.id=sid) into ok;
 if not ok then return jsonb_build_object('ok',false,'message','현재 이동할 수 없는 자리예요.'); end if;
 insert into public.seat_move_requests(student_id,seat_id) values(sid,p_seat_id);
 return jsonb_build_object('ok',true,'message','자리 이동을 신청했어요.','student',private.student_context(sid));
exception when unique_violation then return jsonb_build_object('ok',false,'message','이미 확인을 기다리는 자리 신청이 있어요.');
end $$;

create or replace function public.fo_teacher_login(p_class_code text,p_display_name text,p_pin text) returns jsonb language plpgsql security definer set search_path='' as $$
declare rec record; tid uuid; token text;
begin
 if p_pin !~ '^[0-9]{4}$' then return jsonb_build_object('ok',false,'message','학급코드, 이름, 숫자 4자리 PIN을 확인해 주세요.'); end if;
 delete from private.teacher_sessions where expires_at<=now();
 select t.id,t.account_status,x.pin_hash,x.failed_attempts,x.locked_until into rec from public.teacher_profiles t join public.classrooms c on c.id=t.class_id join private.teacher_credentials x on x.teacher_id=t.id where lower(c.class_code)=lower(trim(p_class_code)) and lower(t.display_name)=lower(trim(p_display_name)) limit 1;
 if rec is null then return jsonb_build_object('ok',false,'message','교사 계정 정보를 확인해 주세요.'); end if;
 if rec.locked_until>now() then return jsonb_build_object('ok',false,'code','LOCKED','message','10분 후 다시 시도해 주세요.'); end if;
 if rec.account_status<>'active' then return jsonb_build_object('ok',false,'message','비활성화된 계정이에요.'); end if;
 if rec.pin_hash<>extensions.crypt(p_pin,rec.pin_hash) then update private.teacher_credentials set failed_attempts=failed_attempts+1,locked_until=case when failed_attempts+1>=5 then now()+interval '10 minutes' end where teacher_id=rec.id; return jsonb_build_object('ok',false,'message','교사 계정 정보를 확인해 주세요.'); end if;
 tid:=rec.id; update private.teacher_credentials set failed_attempts=0,locked_until=null where teacher_id=tid;
 token:=encode(extensions.gen_random_bytes(32),'hex'); insert into private.teacher_sessions values(encode(extensions.digest(token,'sha256'),'hex'),tid,now()+interval '8 hours',now());
 return jsonb_build_object('ok',true,'session_token',token,'teacher',private.teacher_context(tid));
end $$;

create or replace function public.fo_teacher_session(p_session_token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=private.teacher_from_session(p_session_token); begin if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if; return jsonb_build_object('ok',true,'teacher',private.teacher_context(tid)); end $$;

create or replace function public.fo_teacher_logout(p_session_token text) returns jsonb language plpgsql security definer set search_path='' as $$
begin delete from private.teacher_sessions where token_hash=encode(extensions.digest(p_session_token,'sha256'),'hex'); return jsonb_build_object('ok',true); end $$;

create or replace function public.fo_teacher_start_week(p_session_token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=private.teacher_from_session(p_session_token); cid uuid; wid uuid; next_week integer;
begin
 if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 select class_id into cid from public.teacher_profiles where id=tid;
 select id into wid from public.class_weeks where class_id=cid and status='active';
 if wid is null then
   select coalesce(max(week_number),0)+1 into next_week from public.class_weeks where class_id=cid;
   insert into public.class_weeks(class_id,week_number) values(cid,next_week) returning id into wid;
   insert into public.job_postings(week_id,template_id,title,description,world_key,related_job_codes,capacity,reward,duration_minutes,competency_rewards,submission_method)
   select wid,t.id,t.title,t.description,t.world_key,t.related_job_codes,t.capacity,t.reward,t.duration_minutes,t.competency_rewards,t.submission_method from public.job_templates t where t.active order by t.created_at, t.title limit 4;
 end if;
 return jsonb_build_object('ok',true,'message','이번 주 공고를 열었어요.','teacher',private.teacher_context(tid));
end $$;

create or replace function public.fo_teacher_settle_week(p_session_token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=private.teacher_from_session(p_session_token); cid uuid; wid uuid; stu record; salary_amount integer; rent_amount integer;
begin
 if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 select class_id into cid from public.teacher_profiles where id=tid;
 select id into wid from public.class_weeks where class_id=cid and status='active' for update;
 if wid is null then return jsonb_build_object('ok',false,'message','정산할 진행 주차가 없어요.'); end if;
 for stu in select s.id,s.cash from public.student_profiles s where s.class_id=cid and s.account_status='active' order by s.id for update loop
   select coalesce(cjs.salary,j.default_salary,800) into salary_amount from public.student_profiles s left join public.student_job_assignments a on a.student_id=s.id and a.ended_at is null left join public.jobs j on j.code=a.job_code left join public.class_job_settings cjs on cjs.class_id=cid and cjs.job_code=j.code where s.id=stu.id;
   perform private.apply_transaction(stu.id,'salary',salary_amount,0,'salary:'||wid||':'||stu.id,'class_week',wid::text,tid::text);
   update public.student_progress set first_salary_received=true where student_id=stu.id;
   perform private.unlock_feature(stu.id,'wallet','주간 급여'); perform private.unlock_feature(stu.id,'bank','주간 급여');
   select rent into rent_amount from public.seats where student_id=stu.id;
   if rent_amount is not null then
     begin perform private.apply_transaction(stu.id,'rent',-rent_amount,0,'rent:'||wid||':'||stu.id,'class_week',wid::text,tid::text);
     exception when others then insert into public.exception_flags(class_id,student_id,flag_type,title,detail,source_key) values(cid,stu.id,'rent_shortage','월세 납부가 어려워요','주간 정산 시 현금이 부족했습니다.','rent:'||wid||':'||stu.id) on conflict(source_key) do nothing; end;
   end if;
 end loop;
 update public.class_weeks set status='settled',settled_at=now() where id=wid;
 return jsonb_build_object('ok',true,'message','급여와 월세를 안전하게 정산했어요.','teacher',private.teacher_context(tid));
end $$;

create or replace function public.fo_teacher_review_bank(p_session_token text,p_request_id uuid,p_decision text) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=private.teacher_from_session(p_session_token); req record; cid uuid; cash_change integer;
begin
 if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 select class_id into cid from public.teacher_profiles where id=tid;
 select br.* into req from public.bank_requests br join public.student_profiles s on s.id=br.student_id where br.id=p_request_id and br.status='pending' and s.class_id=cid for update of br;
 if req is null then return jsonb_build_object('ok',false,'message','이미 처리된 신청이에요.'); end if;
 if p_decision='reject' then update public.bank_requests set status='rejected',reviewed_by_teacher_id=tid,reviewed_at=now() where id=req.id;
 elsif p_decision='approve' then cash_change:=case when req.request_type='saving' then -req.amount else req.amount end; begin perform private.apply_transaction(req.student_id,req.request_type,cash_change,-cash_change,'bank_request:'||req.id,'bank_request',req.id::text,tid::text); exception when others then return jsonb_build_object('ok',false,'message','학생 잔액이 달라져 처리하지 못했어요.'); end; update public.bank_requests set status='approved',reviewed_by_teacher_id=tid,reviewed_at=now() where id=req.id; perform private.refresh_student_rewards(req.student_id);
 else return jsonb_build_object('ok',false,'message','승인 또는 반려를 선택해 주세요.'); end if;
 return jsonb_build_object('ok',true,'message','은행 신청을 처리했어요.','teacher',private.teacher_context(tid));
end $$;

-- Replace the early direct-saving RPC with the request/approval workflow.
create or replace function public.fo_student_save(p_session_token text,p_amount integer) returns jsonb language sql security definer set search_path='' as $$ select public.fo_student_bank_request(p_session_token,'saving',p_amount) $$;

do $$ declare fn record; begin
  for fn in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('fo_student_apply','fo_student_complete_job','fo_student_bank_request','fo_student_review_bank','fo_student_donate','fo_student_equip_room','fo_student_request_seat','fo_teacher_login','fo_teacher_session','fo_teacher_logout','fo_teacher_start_week','fo_teacher_settle_week','fo_teacher_review_bank') loop
    execute format('revoke all on function %s from public, authenticated',fn.signature);
    execute format('grant execute on function %s to anon',fn.signature);
  end loop;
end $$;

revoke all on function private.teacher_from_session(text),private.apply_transaction(uuid,text,integer,integer,text,text,text,text),private.refresh_student_rewards(uuid),private.teacher_context(uuid) from public,anon,authenticated;

commit;
