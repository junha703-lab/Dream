begin;

-- Durable student expression and job-to-job workflow links.
create table if not exists public.student_avatars (
  student_id uuid primary key references public.student_profiles(id) on delete cascade,
  hair text not null default 'short' check (hair in ('short','wave','bob','spiky')),
  background text not null default 'violet' check (background in ('violet','forest','sunset','sky','maker')),
  displayed_badge_key text references public.badges(key) on delete set null,
  updated_at timestamptz not null default now()
);

create table if not exists public.job_followup_rules (
  source_template_id uuid not null references public.job_templates(id) on delete cascade,
  target_template_id uuid not null references public.job_templates(id) on delete cascade,
  reason text not null,
  active boolean not null default true,
  primary key (source_template_id,target_template_id),
  check (source_template_id<>target_template_id)
);

alter table public.job_templates add column if not exists class_id uuid references public.classrooms(id) on delete cascade;
alter table public.classrooms add column if not exists grade integer not null default 6 check (grade between 1 and 6);
alter table public.classrooms add column if not exists section integer not null default 1 check (section between 1 and 30);
alter table public.job_templates drop constraint if exists job_templates_title_key;
create unique index if not exists job_templates_scope_title_idx on public.job_templates(coalesce(class_id,'00000000-0000-0000-0000-000000000000'::uuid),lower(title));
create unique index if not exists job_postings_week_template_unique_idx on public.job_postings(week_id,template_id) where template_id is not null;
create index if not exists job_templates_class_active_idx on public.job_templates(class_id,active);
create index if not exists job_followup_target_idx on public.job_followup_rules(target_template_id);
create index if not exists student_avatars_badge_idx on public.student_avatars(displayed_badge_key);

alter table public.student_avatars enable row level security;
alter table public.job_followup_rules enable row level security;
drop policy if exists student_avatars_no_direct_access on public.student_avatars;
create policy student_avatars_no_direct_access on public.student_avatars for all to anon,authenticated using(false) with check(false);
drop policy if exists job_followup_rules_no_direct_access on public.job_followup_rules;
create policy job_followup_rules_no_direct_access on public.job_followup_rules for all to anon,authenticated using(false) with check(false);
revoke all on public.student_avatars,public.job_followup_rules from anon,authenticated;

insert into public.student_avatars(student_id)
select id from public.student_profiles on conflict do nothing;

insert into public.job_followup_rules(source_template_id,target_template_id,reason)
select s.id,t.id,v.reason
from (values
 ('교실 물품 점검','수납방법 개선','점검 결과를 실제 공간 개선 업무로 연결'),
 ('교실 불편사항 조사','수납방법 개선','조사한 불편을 제작·공학 해결 업무로 연결'),
 ('행사 준비','행사 포스터 만들기','행사 계획에 필요한 홍보물 제작'),
 ('행사 준비','학급신문 만들기','행사 소식 취재와 기록으로 연결'),
 ('학급 만족도 조사','학급 설문 분석','모은 의견을 데이터 분석 업무로 연결'),
 ('학급신문 만들기','학급 안내판 제작','완성한 소식을 교실 공간에 알리는 업무로 연결')
) v(source_title,target_title,reason)
join public.job_templates s on s.title=v.source_title and s.class_id is null
join public.job_templates t on t.title=v.target_title and t.class_id is null
on conflict(source_template_id,target_template_id) do update set reason=excluded.reason,active=true;

create or replace function private.open_followup_postings(p_posting_id uuid) returns integer language plpgsql security definer set search_path='' as $$
declare opened integer:=0;
begin
  insert into public.job_postings(week_id,template_id,title,description,world_key,related_job_codes,capacity,reward,duration_minutes,competency_rewards,submission_method)
  select source.week_id,target.id,target.title,target.description,target.world_key,target.related_job_codes,target.capacity,target.reward,target.duration_minutes,target.competency_rewards,target.submission_method
  from public.job_postings source
  join public.job_followup_rules rule on rule.source_template_id=source.template_id and rule.active
  join public.job_templates target on target.id=rule.target_template_id and target.active
  join public.class_weeks week on week.id=source.week_id and week.status='active'
  where source.id=p_posting_id
  on conflict do nothing;
  get diagnostics opened=row_count;
  return opened;
end $$;

create or replace function private.refresh_class_exceptions(p_class_id uuid,p_week_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare current_week integer;
begin
  select week_number into current_week from public.class_weeks where id=p_week_id and class_id=p_class_id;

  insert into public.exception_flags(class_id,student_id,flag_type,title,detail,source_key)
  select p_class_id,s.id,'non_participation','2주 이상 공고 미참여','최근 두 주 동안 공고 지원 기록이 없습니다.','nonparticipation:'||p_class_id||':'||s.id||':'||current_week
  from public.student_profiles s
  where s.class_id=p_class_id and s.account_status='active'
    and (select count(*) from public.class_weeks w where w.class_id=p_class_id and w.week_number between current_week-1 and current_week)>=2
    and not exists(
      select 1 from public.job_applications a join public.job_postings p on p.id=a.posting_id join public.class_weeks w on w.id=p.week_id
      where a.student_id=s.id and w.class_id=p_class_id and w.week_number between current_week-1 and current_week
    )
  on conflict(source_key) do nothing;

  insert into public.exception_flags(class_id,student_id,flag_type,title,detail,source_key)
  select p_class_id,s.id,'repeated_incomplete','반복적인 업무 미완료','최근 두 주 동안 완료하지 않은 배정 업무가 2건 이상입니다.','incomplete:'||p_class_id||':'||s.id||':'||current_week
  from public.student_profiles s
  where s.class_id=p_class_id and s.account_status='active'
    and (select count(*) from public.job_applications a join public.job_postings p on p.id=a.posting_id join public.class_weeks w on w.id=p.week_id where a.student_id=s.id and w.week_number between current_week-1 and current_week and a.status in ('assigned','submitted'))>=2
  on conflict(source_key) do nothing;

  insert into public.exception_flags(class_id,student_id,flag_type,title,detail,source_key)
  select p_class_id,br.student_id,'bank_pending','은행 승인 장기 대기','저축·출금 신청이 3일 이상 처리되지 않았습니다.','bank_pending:'||br.id
  from public.bank_requests br join public.student_profiles s on s.id=br.student_id
  where s.class_id=p_class_id and br.status='pending' and br.requested_at<now()-interval '3 days'
  on conflict(source_key) do nothing;

  insert into public.exception_flags(class_id,student_id,flag_type,title,detail,source_key)
  select p_class_id,r.student_id,'seat_pending','자리 이동 승인 장기 대기','자리 이동 신청이 3일 이상 처리되지 않았습니다.','seat_pending:'||r.id
  from public.seat_move_requests r join public.student_profiles s on s.id=r.student_id
  where s.class_id=p_class_id and r.status='pending' and r.requested_at<now()-interval '3 days'
  on conflict(source_key) do nothing;
end $$;

create or replace function private.student_context(p_student_id uuid) returns jsonb language sql security definer set search_path='' as $$
select jsonb_build_object(
 'student_id',s.id,'display_name',s.display_name,'student_number',s.student_number,'first_login',s.first_login,'account_status',s.account_status,
 'basic_job',coalesce(j.title,s.basic_job),'job_world',w.name,'cash',s.cash,'savings',s.savings,'housing_name',coalesce(seat.name,s.housing_name),
 'growth_stage',p.growth_stage,'basic_job_tasks_completed',p.basic_job_tasks_completed,'jobs_completed',p.jobs_completed,
 'first_salary_received',p.first_salary_received,'first_saving_completed',p.first_saving_completed,'saving_goal_reached',p.saving_goal_reached,
 'donation_count',p.donation_count,'total_donation',p.total_donation,
 'feature_unlocks',coalesce((select jsonb_agg(feature_key order by unlocked_at) from public.feature_unlocks where student_id=s.id),'[]'::jsonb),
 'competencies',coalesce((select jsonb_agg(jsonb_build_object('key',c.key,'name',c.name,'description',c.description,'xp',coalesce(sc.xp,0),'color',c.color) order by c.sort_order) from public.competencies c left join public.student_competencies sc on sc.competency_key=c.key and sc.student_id=s.id),'[]'::jsonb),
 'postings',coalesce((select jsonb_agg(jsonb_build_object('id',jp.id,'title',jp.title,'description',jp.description,'world',jw.name,'related_job_codes',jp.related_job_codes,'capacity',jp.capacity,'reward',jp.reward,'duration_minutes',jp.duration_minutes,'competency_rewards',jp.competency_rewards,'submission_method',jp.submission_method,'status',jp.status,'assigned_count',(select count(*) from public.job_applications a where a.posting_id=jp.id and a.status in ('assigned','submitted','completed'))) order by jp.created_at) from public.job_postings jp join public.class_weeks cw on cw.id=jp.week_id join public.job_worlds jw on jw.key=jp.world_key where cw.class_id=s.class_id and cw.status='active' and jp.status='open'),'[]'::jsonb),
 'applications',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'posting_id',a.posting_id,'title',jp.title,'world',jw.name,'related_job_codes',jp.related_job_codes,'status',a.status,'summary',a.summary,'result_url',a.result_url,'fun_rating',a.fun_rating,'difficulty_rating',a.difficulty_rating,'completed_at',a.completed_at) order by a.applied_at desc) from public.job_applications a join public.job_postings jp on jp.id=a.posting_id join public.job_worlds jw on jw.key=jp.world_key where a.student_id=s.id),'[]'::jsonb),
 'career_experiences',coalesce((select jsonb_agg(jsonb_build_object('job',q.title,'count',q.experience_count,'kind',q.kind) order by q.kind,q.experience_count desc,q.title) from (
   select coalesce(j.title,s.basic_job) title,p.basic_job_tasks_completed experience_count,'기본직업' kind where p.basic_job_tasks_completed>0
   union all
   select job.title,count(*)::integer,'공고 경험' from public.job_applications ja join public.job_postings jp on jp.id=ja.posting_id cross join lateral unnest(jp.related_job_codes) as selected(code) join public.jobs job on job.code=selected.code where ja.student_id=s.id and ja.status='completed' group by job.title
 )q),'[]'::jsonb),
 'transactions',coalesce((select jsonb_agg(x order by x.created_at desc) from (select id,transaction_type,cash_delta,savings_delta,cash_after,savings_after,created_at from public.economy_transactions where student_id=s.id order by created_at desc limit 20)x),'[]'::jsonb),
 'bank_requests',coalesce((select jsonb_agg(x order by x.requested_at desc) from (select id,request_type,amount,status,requested_at from public.bank_requests where student_id=s.id order by requested_at desc limit 12)x),'[]'::jsonb),
 'bank_queue',case when coalesce(j.code,'')='banker' then coalesce((select jsonb_agg(jsonb_build_object('id',br.id,'student_name',sp.display_name,'request_type',br.request_type,'amount',br.amount,'requested_at',br.requested_at) order by br.requested_at) from public.bank_requests br join public.student_profiles sp on sp.id=br.student_id where sp.class_id=s.class_id and br.status='pending' and br.student_id<>s.id),'[]'::jsonb) else '[]'::jsonb end,
 'badges',coalesce((select jsonb_agg(jsonb_build_object('key',b.key,'name',b.name,'description',b.description,'icon',b.icon,'awarded_at',sb.awarded_at) order by sb.awarded_at) from public.student_badges sb join public.badges b on b.key=sb.badge_key where sb.student_id=s.id),'[]'::jsonb),
 'avatar',coalesce((select jsonb_build_object('hair',v.hair,'background',v.background,'displayed_badge_key',v.displayed_badge_key) from public.student_avatars v where v.student_id=s.id),jsonb_build_object('hair','short','background','violet','displayed_badge_key',null)),
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

create or replace function private.teacher_full_context(tid uuid) returns jsonb language sql security definer set search_path='' as $$
select coalesce(private.teacher_context(tid),'{}'::jsonb) || jsonb_build_object(
 'grade',(select c.grade from public.teacher_profiles t join public.classrooms c on c.id=t.class_id where t.id=tid),
 'section',(select c.section from public.teacher_profiles t join public.classrooms c on c.id=t.class_id where t.id=tid),
 'job_catalog',coalesce((select jsonb_agg(jsonb_build_object('code',j.code,'title',j.title,'description',j.description,'world',w.name,'salary',coalesce(cjs.salary,j.default_salary)) order by w.sort_order,j.title) from public.teacher_profiles t join public.jobs j on j.active join public.job_worlds w on w.key=j.world_key left join public.class_job_settings cjs on cjs.class_id=t.class_id and cjs.job_code=j.code where t.id=tid),'[]'::jsonb),
 'templates',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'title',x.title,'description',x.description,'world_key',x.world_key,'world',w.name,'related_job_codes',x.related_job_codes,'capacity',x.capacity,'reward',x.reward,'duration_minutes',x.duration_minutes,'competency_rewards',x.competency_rewards,'submission_method',x.submission_method,'repeatable',x.repeatable,'custom',x.class_id is not null) order by x.class_id nulls first,x.title) from public.teacher_profiles t join public.job_templates x on x.active and (x.class_id is null or x.class_id=t.class_id) join public.job_worlds w on w.key=x.world_key where t.id=tid),'[]'::jsonb),
 'seat_catalog',coalesce((select jsonb_agg(jsonb_build_object('id',seat.id,'code',seat.code,'name',seat.name,'type',seat.seat_type,'rent',seat.rent,'move_cost',seat.move_cost,'student_name',s.display_name,'active',seat.active) order by seat.code) from public.teacher_profiles t join public.seats seat on seat.class_id=t.class_id left join public.student_profiles s on s.id=seat.student_id where t.id=tid),'[]'::jsonb),
 'seat_requests',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'student_name',s.display_name,'seat_name',seat.name,'seat_type',seat.seat_type,'move_cost',seat.move_cost,'status',r.status) order by r.requested_at) from public.seat_move_requests r join public.student_profiles s on s.id=r.student_id join public.seats seat on seat.id=r.seat_id join public.teacher_profiles t on t.class_id=s.class_id where t.id=tid and r.status='pending'),'[]'::jsonb),
 'community_goal',coalesce((select jsonb_build_object('id',g.id,'title',g.title,'description',g.description,'target_amount',g.target_amount,'current_amount',coalesce(sum(d.amount),0),'min_donations',g.min_donations_per_student,'status',g.status) from public.community_goals g left join public.donations d on d.goal_id=g.id join public.teacher_profiles t on t.class_id=g.class_id where t.id=tid and g.status in ('active','achieved') group by g.id order by g.created_at desc limit 1),'{}'::jsonb)
)
$$;

create or replace function public.fo_student_update_avatar(p_session_token text,p_hair text,p_background text,p_badge_key text) returns jsonb language plpgsql security definer set search_path='' as $$
declare sid uuid:=private.session_student(p_session_token);
begin
 if sid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 if p_hair not in ('short','wave','bob','spiky') or p_background not in ('violet','forest','sunset','sky','maker') then return jsonb_build_object('ok',false,'message','선택할 수 없는 캐릭터 꾸미기예요.'); end if;
 if nullif(p_badge_key,'') is not null and not exists(select 1 from public.student_badges where student_id=sid and badge_key=p_badge_key) then return jsonb_build_object('ok',false,'message','아직 얻지 않은 배지예요.'); end if;
 insert into public.student_avatars(student_id,hair,background,displayed_badge_key) values(sid,p_hair,p_background,nullif(p_badge_key,'')) on conflict(student_id) do update set hair=excluded.hair,background=excluded.background,displayed_badge_key=excluded.displayed_badge_key,updated_at=now();
 return jsonb_build_object('ok',true,'message','캐릭터 모습을 저장했어요.','student',private.student_context(sid));
end $$;

create or replace function public.fo_student_complete_job(p_session_token text,p_application_id uuid,p_summary text,p_result_url text,p_fun integer,p_difficulty integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare sid uuid:=private.session_student(p_session_token); app record; kv record; opened integer:=0; result_value text:=nullif(trim(coalesce(p_result_url,'')),'');
begin
 if sid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 if length(trim(coalesce(p_summary,'')))<5 or p_fun not between 1 and 5 or p_difficulty not between 1 and 5 then return jsonb_build_object('ok',false,'message','한 일과 느낌을 조금 더 기록해 주세요.'); end if;
 if result_value is not null and not ((result_value~'^https?://.{1,990}$') or (length(result_value)<=1000000 and result_value~'^data:image/(jpeg|png|webp);base64,')) then return jsonb_build_object('ok',false,'message','사진은 750KB 이하 JPG·PNG·WEBP 파일 또는 안전한 링크만 사용할 수 있어요.'); end if;
 select a.*,p.reward,p.competency_rewards,p.world_key into app from public.job_applications a join public.job_postings p on p.id=a.posting_id where a.id=p_application_id and a.student_id=sid for update of a;
 if app is null or app.status not in ('assigned','submitted') then return jsonb_build_object('ok',false,'message','완료할 수 없는 업무예요.'); end if;
 update public.job_applications set status='completed',summary=trim(p_summary),result_url=result_value,fun_rating=p_fun,difficulty_rating=p_difficulty,completed_at=now(),reward_paid=true where id=app.id;
 perform private.apply_transaction(sid,'job_reward',app.reward,0,'job_reward:'||app.id,'job_application',app.id::text,'system');
 for kv in select key,value from jsonb_each_text(app.competency_rewards) loop
   insert into public.competency_events(student_id,competency_key,amount,source_type,source_id) values(sid,kv.key,kv.value::integer,'job_application',app.id) on conflict do nothing;
   if found then insert into public.student_competencies(student_id,competency_key,xp) values(sid,kv.key,kv.value::integer) on conflict(student_id,competency_key) do update set xp=public.student_competencies.xp+excluded.xp,updated_at=now(); end if;
 end loop;
 if app.world_key='make' then insert into public.student_badges values(sid,'maker',now(),'만들고 해결하는 업무 완료') on conflict do nothing; end if;
 if app.world_key='express' and (select count(*) from public.job_applications a join public.job_postings p on p.id=a.posting_id where a.student_id=sid and a.status='completed' and p.world_key='express')>=2 then insert into public.student_badges values(sid,'design',now(),'표현 분야 업무 2회 완료') on conflict do nothing; end if;
 opened:=private.open_followup_postings(app.posting_id);
 perform private.refresh_student_rewards(sid);
 return jsonb_build_object('ok',true,'message',case when opened>0 then '업무가 완료되어 다음 연결 공고도 열렸어요.' else '업무 기록과 보상, 핵심역량이 반영됐어요.' end,'student',private.student_context(sid));
end $$;

create or replace function public.fo_complete_basic_task(p_session_token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare sid uuid:=private.session_student(p_session_token); n integer; paid boolean; salary_amount integer;
begin
 if sid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 select basic_job_tasks_completed,first_salary_received into n,paid from public.student_progress where student_id=sid for update;
 update public.student_progress set basic_job_tasks_completed=n+1,growth_stage=greatest(growth_stage,case when n+1>=2 then 3 else 2 end),updated_at=now() where student_id=sid;
 if not paid then
   select coalesce(cjs.salary,j.default_salary,800) into salary_amount from public.student_profiles s left join public.student_job_assignments a on a.student_id=s.id and a.ended_at is null left join public.jobs j on j.code=a.job_code left join public.class_job_settings cjs on cjs.class_id=s.class_id and cjs.job_code=j.code where s.id=sid;
   perform private.apply_transaction(sid,'salary',salary_amount,0,'first_salary:'||sid,'basic_task',sid::text,'system');
   update public.student_progress set first_salary_received=true where student_id=sid;
   perform private.unlock_feature(sid,'wallet','첫 월급'); perform private.unlock_feature(sid,'bank','첫 월급'); perform private.unlock_feature(sid,'community_fund','첫 월급');
 end if;
 if n+1>=2 then perform private.unlock_feature(sid,'job_board','기본업무 2회'); end if;
 if n+1>=4 then perform private.unlock_feature(sid,'competencies','업무 경험 4회'); end if;
 return jsonb_build_object('ok',true,'message','기본직업 업무를 기록했어요.','student',private.student_context(sid));
end $$;

drop function if exists public.fo_teacher_update_class(text,text,text);
create or replace function public.fo_teacher_update_class(p_session_token text,p_name text,p_grade integer,p_section integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=private.teacher_from_session(p_session_token); cid uuid;
begin
 if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 if length(trim(p_name))<2 or p_grade not between 1 and 6 or p_section not between 1 and 30 then return jsonb_build_object('ok',false,'message','학급 이름, 학년, 반을 확인해 주세요.'); end if;
 select class_id into cid from public.teacher_profiles where id=tid;
 update public.classrooms set name=trim(p_name),grade=p_grade,section=p_section where id=cid;
 return jsonb_build_object('ok',true,'message','학급 기본 정보를 저장했어요.');
end $$;

create or replace function public.fo_teacher_update_salary(p_session_token text,p_job_code text,p_salary integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=private.teacher_from_session(p_session_token); cid uuid;
begin
 if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 if p_salary<100 or p_salary>5000 or p_salary%10<>0 or not exists(select 1 from public.jobs where code=p_job_code and active) then return jsonb_build_object('ok',false,'message','직업과 월급을 확인해 주세요.'); end if;
 select class_id into cid from public.teacher_profiles where id=tid;
 insert into public.class_job_settings(class_id,job_code,salary) values(cid,p_job_code,p_salary) on conflict(class_id,job_code) do update set salary=excluded.salary;
 return jsonb_build_object('ok',true,'message','직업 월급을 저장했어요.');
end $$;

create or replace function public.fo_teacher_update_seat(p_session_token text,p_seat_id uuid,p_name text,p_type text,p_rent integer,p_move_cost integer,p_active boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=private.teacher_from_session(p_session_token); cid uuid;
begin
 if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 if length(trim(p_name))<2 or p_type not in ('기본형','조용한형','창가형','협업형') or p_rent<0 or p_rent>5000 or p_move_cost<0 or p_move_cost>5000 then return jsonb_build_object('ok',false,'message','자리 이름·유형·비용을 확인해 주세요.'); end if;
 select class_id into cid from public.teacher_profiles where id=tid;
 update public.seats set name=trim(p_name),seat_type=p_type,rent=p_rent,move_cost=p_move_cost,active=p_active where id=p_seat_id and class_id=cid;
 if not found then return jsonb_build_object('ok',false,'message','관리할 수 없는 자리예요.'); end if;
 return jsonb_build_object('ok',true,'message','자리 설정을 저장했어요.');
end $$;

create or replace function public.fo_teacher_upsert_goal(p_session_token text,p_title text,p_description text,p_target integer,p_min_donations integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=private.teacher_from_session(p_session_token); cid uuid; gid uuid; goal_status text;
begin
 if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 if length(trim(p_title))<2 or length(trim(p_description))<5 or p_target<100 or p_target>1000000 or p_min_donations<1 or p_min_donations>20 then return jsonb_build_object('ok',false,'message','공동체 목표 내용을 확인해 주세요.'); end if;
 select class_id into cid from public.teacher_profiles where id=tid;
 select id,status into gid,goal_status from public.community_goals where class_id=cid and status in ('active','achieved') order by created_at desc limit 1 for update;
 if gid is null or goal_status='achieved' then
   update public.community_goals set status='closed' where class_id=cid and status='achieved';
   insert into public.community_goals(class_id,title,description,target_amount,min_donations_per_student) values(cid,trim(p_title),trim(p_description),p_target,p_min_donations);
 else
   update public.community_goals set title=trim(p_title),description=trim(p_description),target_amount=p_target,min_donations_per_student=p_min_donations where id=gid;
 end if;
 return jsonb_build_object('ok',true,'message','공동체 목표를 저장했어요.');
end $$;

create or replace function public.fo_teacher_create_template(p_session_token text,p_title text,p_description text,p_world_key text,p_related_job_codes text[],p_capacity integer,p_reward integer,p_duration integer,p_competency_rewards jsonb,p_submission_method text,p_repeatable boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=private.teacher_from_session(p_session_token); cid uuid; kv record;
begin
 if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 if length(trim(p_title))<3 or length(trim(p_description))<10 or p_capacity not between 1 and 30 or p_reward not between 0 and 5000 or p_duration not between 5 and 240 or length(trim(p_submission_method))<2 then return jsonb_build_object('ok',false,'message','공고 템플릿 내용을 확인해 주세요.'); end if;
 if coalesce(cardinality(p_related_job_codes),0)=0 or not exists(select 1 from public.job_worlds where key=p_world_key) or exists(select 1 from unnest(p_related_job_codes) as selected(code) where not exists(select 1 from public.jobs j where j.code=selected.code and j.active)) then return jsonb_build_object('ok',false,'message','직업 세계와 관련 직업을 확인해 주세요.'); end if;
 if jsonb_typeof(p_competency_rewards)<>'object' or p_competency_rewards='{}'::jsonb then return jsonb_build_object('ok',false,'message','성장할 핵심역량을 한 가지 이상 골라 주세요.'); end if;
 for kv in select key,value from jsonb_each_text(p_competency_rewards) loop
   if not exists(select 1 from public.competencies where key=kv.key) or kv.value::integer not between 1 and 5 then return jsonb_build_object('ok',false,'message','핵심역량 경험치는 1~5로 설정해 주세요.'); end if;
 end loop;
 select class_id into cid from public.teacher_profiles where id=tid;
 insert into public.job_templates(class_id,title,description,world_key,related_job_codes,capacity,reward,duration_minutes,competency_rewards,submission_method,repeatable) values(cid,trim(p_title),trim(p_description),p_world_key,p_related_job_codes,p_capacity,p_reward,p_duration,p_competency_rewards,trim(p_submission_method),p_repeatable);
 return jsonb_build_object('ok',true,'message','우리 반 공고 템플릿을 만들었어요.');
exception when unique_violation then return jsonb_build_object('ok',false,'message','같은 이름의 템플릿이 이미 있어요.');
end $$;

create or replace function public.fo_teacher_open_template(p_session_token text,p_template_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=private.teacher_from_session(p_session_token); cid uuid; wid uuid;
begin
 if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 select class_id into cid from public.teacher_profiles where id=tid;
 select id into wid from public.class_weeks where class_id=cid and status='active';
 if wid is null then return jsonb_build_object('ok',false,'message','먼저 이번 주를 시작해 주세요.'); end if;
 insert into public.job_postings(week_id,template_id,title,description,world_key,related_job_codes,capacity,reward,duration_minutes,competency_rewards,submission_method)
 select wid,id,title,description,world_key,related_job_codes,capacity,reward,duration_minutes,competency_rewards,submission_method from public.job_templates where id=p_template_id and active and (class_id is null or class_id=cid)
 on conflict do nothing;
 if not found then return jsonb_build_object('ok',false,'message','이미 열렸거나 사용할 수 없는 템플릿이에요.'); end if;
 return jsonb_build_object('ok',true,'message','공고를 이번 주에 추가했어요.');
end $$;

create or replace function public.fo_teacher_resolve_exception(p_session_token text,p_exception_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=private.teacher_from_session(p_session_token); cid uuid;
begin
 if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 select class_id into cid from public.teacher_profiles where id=tid;
 update public.exception_flags set status='resolved',resolved_at=now() where id=p_exception_id and class_id=cid and status='open';
 if not found then return jsonb_build_object('ok',false,'message','이미 확인했거나 찾을 수 없는 항목이에요.'); end if;
 return jsonb_build_object('ok',true,'message','확인 완료로 정리했어요.');
end $$;

create or replace function public.fo_teacher_review_bank(p_session_token text,p_request_id uuid,p_decision text) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=private.teacher_from_session(p_session_token); req record; cid uuid; cash_change integer;
begin
 if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 select class_id into cid from public.teacher_profiles where id=tid;
 select br.* into req from public.bank_requests br join public.student_profiles s on s.id=br.student_id where br.id=p_request_id and br.status='pending' and s.class_id=cid for update of br;
 if req is null then return jsonb_build_object('ok',false,'message','이미 처리된 신청이에요.'); end if;
 if p_decision='reject' then update public.bank_requests set status='rejected',reviewed_by_teacher_id=tid,reviewed_at=now() where id=req.id;
 elsif p_decision='approve' then
   cash_change:=case when req.request_type='saving' then -req.amount else req.amount end;
   begin perform private.apply_transaction(req.student_id,req.request_type,cash_change,-cash_change,'bank_request:'||req.id,'bank_request',req.id::text,tid::text); exception when others then return jsonb_build_object('ok',false,'message','학생 잔액이 달라져 처리하지 못했어요.'); end;
   update public.bank_requests set status='approved',reviewed_by_teacher_id=tid,reviewed_at=now() where id=req.id;
   update public.student_progress set first_saving_completed=first_saving_completed or req.request_type='saving',saving_goal_reached=saving_goal_reached or (select savings>=3000 from public.student_profiles where id=req.student_id),updated_at=now() where student_id=req.student_id;
   if req.request_type='saving' then perform private.unlock_feature(req.student_id,'housing','첫 저축'); insert into public.student_badges values(req.student_id,'finance',now(),'은행 거래 완료') on conflict do nothing; end if;
   perform private.refresh_student_rewards(req.student_id);
 else return jsonb_build_object('ok',false,'message','승인 또는 반려를 선택해 주세요.'); end if;
 return jsonb_build_object('ok',true,'message','은행 신청을 처리했어요.');
end $$;

create or replace function public.fo_teacher_settle_week(p_session_token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=private.teacher_from_session(p_session_token); cid uuid; wid uuid; stu record; salary_amount integer; rent_amount integer;
begin
 if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 select class_id into cid from public.teacher_profiles where id=tid;
 select id into wid from public.class_weeks where class_id=cid and status='active' for update;
 if wid is null then return jsonb_build_object('ok',false,'message','정산할 진행 주차가 없어요.'); end if;
 for stu in select s.id from public.student_profiles s where s.class_id=cid and s.account_status='active' order by s.id for update loop
   select coalesce(cjs.salary,j.default_salary,800) into salary_amount from public.student_profiles s left join public.student_job_assignments a on a.student_id=s.id and a.ended_at is null left join public.jobs j on j.code=a.job_code left join public.class_job_settings cjs on cjs.class_id=cid and cjs.job_code=j.code where s.id=stu.id;
   perform private.apply_transaction(stu.id,'salary',salary_amount,0,'salary:'||wid||':'||stu.id,'class_week',wid::text,tid::text);
   update public.student_progress set first_salary_received=true where student_id=stu.id;
   perform private.unlock_feature(stu.id,'wallet','주간 급여'); perform private.unlock_feature(stu.id,'bank','주간 급여');
   select rent into rent_amount from public.seats where student_id=stu.id;
   if rent_amount is not null then
     begin perform private.apply_transaction(stu.id,'rent',-rent_amount,0,'rent:'||wid||':'||stu.id,'class_week',wid::text,tid::text);
     exception when others then insert into public.exception_flags(class_id,student_id,flag_type,title,detail,source_key) values(cid,stu.id,'rent_shortage','월세 납부가 어려워요','주간 정산 시 현금이 부족했습니다.','rent:'||wid||':'||stu.id) on conflict(source_key) do nothing; end;
   end if;
   perform private.refresh_student_rewards(stu.id);
 end loop;
 perform private.refresh_class_exceptions(cid,wid);
 update public.class_weeks set status='settled',settled_at=now() where id=wid;
 return jsonb_build_object('ok',true,'message','급여·월세·성장 기록과 예외 확인을 정산했어요.');
end $$;

do $$ declare fn record; begin
 for fn in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('fo_student_update_avatar','fo_teacher_update_class','fo_teacher_update_salary','fo_teacher_update_seat','fo_teacher_upsert_goal','fo_teacher_create_template','fo_teacher_resolve_exception') loop
   execute format('revoke all on function %s from public,authenticated',fn.signature);
   execute format('grant execute on function %s to anon',fn.signature);
 end loop;
end $$;

revoke all on function private.open_followup_postings(uuid),private.refresh_class_exceptions(uuid,uuid) from public,anon,authenticated;

commit;
