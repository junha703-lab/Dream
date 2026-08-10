begin;

create table public.basic_job_tasks (
  id uuid primary key default gen_random_uuid(),
  job_code text not null references public.jobs(code) on delete cascade,
  key text not null unique,
  title text not null,
  description text not null,
  proof_mode text not null check (proof_mode in ('system','photo','result','peer','checklist')),
  sort_order integer not null default 0,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.basic_job_submissions (
  id uuid primary key default gen_random_uuid(),
  week_id uuid not null references public.class_weeks(id) on delete cascade,
  task_id uuid not null references public.basic_job_tasks(id) on delete restrict,
  student_id uuid not null references public.student_profiles(id) on delete cascade,
  verifier_student_id uuid references public.student_profiles(id) on delete set null,
  summary text not null,
  evidence_url text,
  status text not null check (status in ('pending_confirmation','confirmed','rejected')),
  source_key text,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  credited_at timestamptz
);

create index basic_job_tasks_job_active_idx on public.basic_job_tasks(job_code,active,sort_order);
create index basic_job_submissions_student_idx on public.basic_job_submissions(student_id,submitted_at desc);
create index basic_job_submissions_verifier_idx on public.basic_job_submissions(verifier_student_id,status,submitted_at);
create unique index basic_job_submissions_open_task_idx
  on public.basic_job_submissions(week_id,student_id,task_id)
  where status in ('pending_confirmation','confirmed');
create unique index basic_job_submissions_source_idx
  on public.basic_job_submissions(source_key)
  where source_key is not null;

alter table public.basic_job_tasks enable row level security;
alter table public.basic_job_submissions enable row level security;
create policy basic_job_tasks_no_direct_access on public.basic_job_tasks for all to anon,authenticated using(false) with check(false);
create policy basic_job_submissions_no_direct_access on public.basic_job_submissions for all to anon,authenticated using(false) with check(false);
revoke all on public.basic_job_tasks,public.basic_job_submissions from anon,authenticated;

insert into public.basic_job_tasks(job_code,key,title,description,proof_mode,sort_order) values
('banker','bank_review','저축·출금 요청 확인','은행 업무 화면에서 친구의 저축 또는 출금 요청을 확인해요.','system',1),
('teacher','teacher_learning_help','친구 학습 돕기','친구에게 학습 내용을 설명하고 이해에 도움이 되었는지 확인해요.','peer',1),
('teacher','teacher_quiz','복습 퀴즈 만들기','배운 내용을 떠올릴 수 있는 짧은 복습 퀴즈를 만들어요.','result',2),
('counselor','counselor_listen','학급 의견 듣기','친구의 학급생활 의견을 존중하며 듣고 핵심을 기록해요.','peer',1),
('counselor','counselor_survey','학급 만족도 정리','민감한 상담 없이 학급생활 만족도나 건의사항을 모아 정리해요.','result',2),
('maker','maker_object','교실 물품 만들기','교실이나 행사에 필요한 간단한 물품 또는 소품을 만들어요.','photo',1),
('maker','maker_storage','수납 방법 개선','교실 물품을 더 편리하게 정리할 방법을 만들고 적용해요.','photo',2),
('engineer','engineer_test','해결안 시험하기','교실의 불편을 해결할 아이디어를 실제로 시험하고 결과를 기록해요.','photo',1),
('engineer','engineer_design','해결 구조 설계하기','물품이나 공간을 개선할 구조·장치 아이디어를 그림이나 글로 설계해요.','result',2),
('reporter','reporter_news','학급 뉴스 작성','학급의 소식을 사실에 맞게 취재하고 알기 쉽게 정리해요.','result',1),
('reporter','reporter_interview','친구 인터뷰','친구의 동의를 받고 질문하고 답변의 핵심을 기록해요.','peer',2),
('designer','designer_poster','포스터·안내물 만들기','행사나 학급 소식을 한눈에 알아볼 수 있는 시각 자료로 만들어요.','photo',1),
('designer','designer_material','발표·게시 자료 디자인','내용의 목적에 맞게 발표자료, 이름표 또는 게시물을 디자인해요.','result',2),
('analyst','analyst_data','설문·투표 결과 분석','설문이나 투표 결과를 표·그래프로 정리하고 의미를 찾아요.','result',1),
('analyst','analyst_problem','데이터로 문제 살피기','학급 문제와 관련된 자료를 모아 근거가 보이게 정리해요.','result',2),
('planner','planner_plan','행사 계획 세우기','행사의 목적, 순서, 준비물과 일정을 계획서로 정리해요.','result',1),
('planner','planner_roles','행사 역할 나누기','친구들의 의견을 듣고 행사 역할을 공정하게 나누어요.','peer',2),
('hr','hr_posting','공고 참여 기록 확인','열린 공고와 참여 기록을 확인하고 빠진 내용을 정리해요.','checklist',1),
('hr','hr_assignment','업무 배정 돕기','지원자의 의견을 듣고 공정한 업무 배정안을 만들어요.','peer',2),
('environment','environment_check','교실 환경 점검','정리, 분리배출, 환기 등 교실 환경을 체크리스트로 살펴요.','checklist',1),
('environment','environment_improve','환경 개선 실천','교실 환경의 전후 모습이 보이도록 한 가지 개선을 실천해요.','photo',2),
('facility','facility_check','교실 물품 안전 점검','책상·의자·교실 물품 상태를 확인하고 점검 결과를 기록해요.','checklist',1),
('facility','facility_report','고장·불편 신고','고장이나 불편을 발견해 사진과 함께 제작자 또는 엔지니어에게 알려요.','photo',2);

create or replace function private.credit_basic_job_submission(p_submission_id uuid) returns boolean
language plpgsql security definer set search_path='' as $$
declare sid uuid; n integer; paid boolean; salary_amount integer;
begin
  select s.student_id into sid
  from public.basic_job_submissions s
  where s.id=p_submission_id and s.status='confirmed' and s.credited_at is null
  for update;
  if sid is null then return false; end if;

  select basic_job_tasks_completed,first_salary_received into n,paid
  from public.student_progress where student_id=sid for update;

  update public.student_progress
  set basic_job_tasks_completed=n+1,
      growth_stage=greatest(growth_stage,case when n+1>=2 then 3 else 2 end),
      updated_at=now()
  where student_id=sid;

  if not paid then
    select coalesce(cjs.salary,j.default_salary,800) into salary_amount
    from public.student_profiles s
    left join public.student_job_assignments a on a.student_id=s.id and a.ended_at is null
    left join public.jobs j on j.code=a.job_code
    left join public.class_job_settings cjs on cjs.class_id=s.class_id and cjs.job_code=j.code
    where s.id=sid;
    perform private.apply_transaction(sid,'salary',salary_amount,0,'first_salary:'||sid,'basic_job_submission',p_submission_id::text,'system');
    update public.student_progress set first_salary_received=true where student_id=sid;
    perform private.unlock_feature(sid,'wallet','첫 월급');
    perform private.unlock_feature(sid,'bank','첫 월급');
    perform private.unlock_feature(sid,'community_fund','첫 월급');
  end if;

  if n+1>=2 then perform private.unlock_feature(sid,'job_board','기본업무 2회'); end if;
  if n+1>=4 then perform private.unlock_feature(sid,'competencies','업무 경험 4회'); end if;
  update public.basic_job_submissions set credited_at=now() where id=p_submission_id;
  return true;
end $$;

alter function private.student_context(uuid) rename to student_context_before_basic_job_evidence;
create function private.student_context(p_student_id uuid) returns jsonb
language sql security definer set search_path='' as $$
select coalesce(private.student_context_before_basic_job_evidence(p_student_id),'{}'::jsonb) || jsonb_build_object(
  'basic_job_task_catalog',coalesce((
    select jsonb_agg(jsonb_build_object('id',t.id,'key',t.key,'title',t.title,'description',t.description,'proof_mode',t.proof_mode) order by t.sort_order,t.title)
    from public.basic_job_tasks t
    join public.student_job_assignments a on a.job_code=t.job_code and a.student_id=p_student_id and a.ended_at is null
    where t.active
  ),'[]'::jsonb),
  'basic_job_submissions',coalesce((
    select jsonb_agg(x order by x.submitted_at desc) from (
      select s.id,s.task_id,t.title,t.proof_mode,s.summary,s.evidence_url,s.status,s.submitted_at,s.reviewed_at,
             v.display_name as verifier_name
      from public.basic_job_submissions s
      join public.basic_job_tasks t on t.id=s.task_id
      left join public.student_profiles v on v.id=s.verifier_student_id
      where s.student_id=p_student_id order by s.submitted_at desc limit 12
    ) x
  ),'[]'::jsonb),
  'peer_review_queue',coalesce((
    select jsonb_agg(jsonb_build_object('id',s.id,'student_name',owner.display_name,'task_title',t.title,'summary',s.summary,'submitted_at',s.submitted_at) order by s.submitted_at)
    from public.basic_job_submissions s
    join public.basic_job_tasks t on t.id=s.task_id
    join public.student_profiles owner on owner.id=s.student_id
    where s.verifier_student_id=p_student_id and s.status='pending_confirmation'
  ),'[]'::jsonb),
  'classmates',coalesce((
    select jsonb_agg(jsonb_build_object('id',mate.id,'name',mate.display_name,'job',coalesce(job.title,mate.basic_job)) order by mate.student_number,mate.display_name)
    from public.student_profiles me
    join public.student_profiles mate on mate.class_id=me.class_id and mate.id<>me.id and mate.account_status='active'
    left join public.student_job_assignments a on a.student_id=mate.id and a.ended_at is null
    left join public.jobs job on job.code=a.job_code
    where me.id=p_student_id
  ),'[]'::jsonb)
)
$$;

create function public.fo_student_submit_basic_task(
  p_session_token text,
  p_task_id uuid,
  p_summary text,
  p_evidence_url text,
  p_verifier_student_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare sid uuid:=private.session_student(p_session_token); task record; wid uuid; evidence_value text:=nullif(trim(coalesce(p_evidence_url,'')),''); submission_id uuid; submission_status text;
begin
  if sid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
  if length(trim(coalesce(p_summary,'')))<5 then return jsonb_build_object('ok',false,'message','무엇을 했는지 한 문장 이상 적어 주세요.'); end if;

  select t.* into task
  from public.basic_job_tasks t
  join public.student_job_assignments a on a.job_code=t.job_code and a.student_id=sid and a.ended_at is null
  where t.id=p_task_id and t.active;
  if task is null then return jsonb_build_object('ok',false,'message','현재 기본직업에서 할 수 없는 업무예요.'); end if;
  if task.proof_mode='system' then return jsonb_build_object('ok',false,'message','이 업무는 앱에서 처리하면 자동으로 기록돼요.'); end if;

  select w.id into wid from public.class_weeks w
  join public.student_profiles s on s.class_id=w.class_id
  where s.id=sid and w.status='active' order by w.week_number desc limit 1;
  if wid is null then return jsonb_build_object('ok',false,'message','선생님이 이번 주를 시작한 뒤 기록할 수 있어요.'); end if;

  if task.proof_mode in ('photo','result') and not (
    (length(evidence_value)<=1000 and evidence_value~'^https?://.+$') or
    (length(evidence_value)<=1000000 and evidence_value~'^data:image/(jpeg|png|webp);base64,')
  ) then return jsonb_build_object('ok',false,'message','사진 또는 결과물 링크를 함께 남겨 주세요. 사진은 750KB 이하 JPG·PNG·WEBP만 가능해요.'); end if;

  if task.proof_mode='peer' then
    if p_verifier_student_id is null or p_verifier_student_id=sid or not exists(
      select 1 from public.student_profiles me join public.student_profiles peer on peer.class_id=me.class_id
      where me.id=sid and peer.id=p_verifier_student_id and peer.account_status='active'
    ) then return jsonb_build_object('ok',false,'message','같은 학급의 확인 친구를 선택해 주세요.'); end if;
    submission_status:='pending_confirmation';
  else
    submission_status:='confirmed';
  end if;

  insert into public.basic_job_submissions(week_id,task_id,student_id,verifier_student_id,summary,evidence_url,status,reviewed_at)
  values(wid,p_task_id,sid,case when task.proof_mode='peer' then p_verifier_student_id end,trim(p_summary),evidence_value,submission_status,case when submission_status='confirmed' then now() end)
  returning id into submission_id;

  if submission_status='confirmed' then perform private.credit_basic_job_submission(submission_id); end if;
  return jsonb_build_object('ok',true,'message',case when submission_status='confirmed' then '기본업무 증거가 기록되고 직업 경험에 반영됐어요.' else '확인 친구에게 요청을 보냈어요. 친구가 확인하면 경험에 반영돼요.' end,'student',private.student_context(sid));
exception when unique_violation then
  return jsonb_build_object('ok',false,'message','이번 주에는 이미 같은 기본업무를 기록했어요.');
end $$;

create function public.fo_student_review_basic_task(p_session_token text,p_submission_id uuid,p_decision text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare reviewer uuid:=private.session_student(p_session_token); submission_owner uuid;
begin
  if reviewer is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
  if p_decision not in ('confirm','reject') then return jsonb_build_object('ok',false,'message','확인 또는 다시 하기를 선택해 주세요.'); end if;

  select student_id into submission_owner from public.basic_job_submissions
  where id=p_submission_id and verifier_student_id=reviewer and status='pending_confirmation'
  for update;
  if submission_owner is null then return jsonb_build_object('ok',false,'message','이미 확인했거나 확인할 수 없는 기록이에요.'); end if;

  update public.basic_job_submissions
  set status=case when p_decision='confirm' then 'confirmed' else 'rejected' end,reviewed_at=now()
  where id=p_submission_id;
  if p_decision='confirm' then perform private.credit_basic_job_submission(p_submission_id); end if;
  return jsonb_build_object('ok',true,'message',case when p_decision='confirm' then '친구의 기본업무를 확인했어요.' else '다시 보완하도록 알려줬어요.' end,'student',private.student_context(reviewer));
end $$;

create or replace function public.fo_complete_basic_task(p_session_token text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare sid uuid:=private.session_student(p_session_token);
begin
  if sid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
  return jsonb_build_object('ok',false,'message','이제 기본업무 카드에서 활동 증거를 남겨 주세요.','student',private.student_context(sid));
end $$;

create or replace function public.fo_student_review_bank(p_session_token text,p_request_id uuid,p_decision text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare reviewer uuid:=private.session_student(p_session_token); req record; reviewer_job text; cash_change integer; savings_change integer; wid uuid; task_id uuid; submission_id uuid;
begin
  if reviewer is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
  select j.code into reviewer_job from public.student_job_assignments a join public.jobs j on j.code=a.job_code where a.student_id=reviewer and a.ended_at is null;
  if reviewer_job<>'banker' then return jsonb_build_object('ok',false,'message','은행원만 확인할 수 있어요.'); end if;
  select br.* into req from public.bank_requests br join public.student_profiles owner on owner.id=br.student_id join public.student_profiles rv on rv.id=reviewer and rv.class_id=owner.class_id where br.id=p_request_id and br.status='pending' and br.student_id<>reviewer for update of br;
  if req is null then return jsonb_build_object('ok',false,'message','이미 처리했거나 확인할 수 없는 요청이에요.'); end if;

  if p_decision='reject' then
    update public.bank_requests set status='rejected',reviewed_by_student_id=reviewer,reviewed_at=now() where id=req.id;
  elsif p_decision='approve' then
    cash_change:=case when req.request_type='saving' then -req.amount else req.amount end;
    savings_change:=-cash_change;
    begin
      perform private.apply_transaction(req.student_id,req.request_type,cash_change,savings_change,'bank_request:'||req.id,'bank_request',req.id::text,reviewer::text);
    exception when others then return jsonb_build_object('ok',false,'message','신청 학생의 금액이 달라져 처리하지 못했어요.'); end;
    update public.bank_requests set status='approved',reviewed_by_student_id=reviewer,reviewed_at=now() where id=req.id;
    update public.student_progress set first_saving_completed=first_saving_completed or req.request_type='saving',saving_goal_reached=saving_goal_reached or (select savings>=3000 from public.student_profiles where id=req.student_id),updated_at=now() where student_id=req.student_id;
    if req.request_type='saving' then
      perform private.unlock_feature(req.student_id,'housing','첫 저축');
      insert into public.student_badges values(req.student_id,'finance',now(),'은행 거래 완료') on conflict do nothing;
    end if;
    perform private.refresh_student_rewards(req.student_id);
  else
    return jsonb_build_object('ok',false,'message','승인 또는 반려를 선택해 주세요.');
  end if;

  select w.id into wid from public.class_weeks w join public.student_profiles s on s.class_id=w.class_id where s.id=reviewer and w.status='active' order by w.week_number desc limit 1;
  select id into task_id from public.basic_job_tasks where key='bank_review' and active;
  if wid is not null and task_id is not null then
    insert into public.basic_job_submissions(week_id,task_id,student_id,summary,status,source_key,reviewed_at)
    values(wid,task_id,reviewer,case when p_decision='approve' then '저축·출금 요청을 확인하고 승인했어요.' else '금액과 내용을 확인하고 요청을 반려했어요.' end,'confirmed','bank_review:'||req.id,now())
    on conflict do nothing returning id into submission_id;
    if submission_id is not null then perform private.credit_basic_job_submission(submission_id); end if;
  end if;
  return jsonb_build_object('ok',true,'message','은행 요청을 처리했고 기본직업 경험에 자동 기록했어요.','student',private.student_context(reviewer));
end $$;

alter function private.refresh_class_exceptions(uuid,uuid) rename to refresh_class_exceptions_before_basic_job_evidence;
create function private.refresh_class_exceptions(p_class_id uuid,p_week_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform private.refresh_class_exceptions_before_basic_job_evidence(p_class_id,p_week_id);
  insert into public.exception_flags(class_id,student_id,flag_type,title,detail,source_key)
  select p_class_id,s.student_id,'basic_job_confirmation_pending','기본업무 친구 확인 대기','친구 확인을 요청한 기본업무가 3일 이상 기다리고 있습니다.','basic_job_pending:'||s.id
  from public.basic_job_submissions s
  join public.student_profiles owner on owner.id=s.student_id
  where owner.class_id=p_class_id and s.status='pending_confirmation' and s.submitted_at<now()-interval '3 days'
  on conflict(source_key) do nothing;
end $$;

revoke all on function private.credit_basic_job_submission(uuid),private.student_context_before_basic_job_evidence(uuid),private.student_context(uuid),private.refresh_class_exceptions_before_basic_job_evidence(uuid,uuid),private.refresh_class_exceptions(uuid,uuid) from public,anon,authenticated;
revoke all on function public.fo_student_submit_basic_task(text,uuid,text,text,uuid),public.fo_student_review_basic_task(text,uuid,text) from public,authenticated;
grant execute on function public.fo_student_submit_basic_task(text,uuid,text,text,uuid),public.fo_student_review_basic_task(text,uuid,text) to anon;

commit;
