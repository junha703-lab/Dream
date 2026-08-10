-- Source copy of the migration applied to the Future Odyssey Supabase project.
create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.classrooms (
  id uuid primary key default gen_random_uuid(), class_code text not null unique,
  name text not null, created_at timestamptz not null default now()
);
create table public.student_profiles (
  id uuid primary key default gen_random_uuid(), auth_user_id uuid not null unique default gen_random_uuid(),
  class_id uuid not null references public.classrooms(id) on delete cascade,
  student_number integer not null check (student_number > 0), display_name text not null,
  role text not null default 'student' check (role = 'student'), first_login boolean not null default true,
  account_status text not null default 'active' check (account_status in ('active','disabled','security_wait')),
  basic_job text, cash integer not null default 0 check (cash >= 0), savings integer not null default 0 check (savings >= 0),
  housing_name text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(class_id, student_number)
);
create table public.student_progress (
  student_id uuid primary key references public.student_profiles(id) on delete cascade,
  growth_stage smallint not null default 1 check (growth_stage between 1 and 6),
  basic_job_tasks_completed integer not null default 0, jobs_completed integer not null default 0,
  unique_job_categories_experienced integer not null default 0, first_salary_received boolean not null default false,
  first_saving_completed boolean not null default false, saving_goal_reached boolean not null default false,
  donation_count integer not null default 0, total_donation integer not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.feature_unlocks (
  id uuid primary key default gen_random_uuid(), student_id uuid not null references public.student_profiles(id) on delete cascade,
  feature_key text not null check (feature_key in ('wallet','bank','housing','job_board','competencies','badges','my_room','community_fund')),
  unlocked_at timestamptz not null default now(), unlock_reason text not null, unique(student_id, feature_key)
);
create table private.student_credentials (
  student_id uuid primary key references public.student_profiles(id) on delete cascade, pin_hash text not null,
  failed_attempts integer not null default 0, locked_until timestamptz, last_failed_at timestamptz, updated_at timestamptz not null default now()
);
create table private.student_sessions (
  token_hash text primary key, student_id uuid not null references public.student_profiles(id) on delete cascade,
  expires_at timestamptz not null, created_at timestamptz not null default now()
);
create index student_sessions_student_idx on private.student_sessions(student_id);
create index student_sessions_expiry_idx on private.student_sessions(expires_at);
create index student_profiles_login_idx on public.student_profiles(class_id, lower(display_name));

alter table public.classrooms enable row level security;
alter table public.student_profiles enable row level security;
alter table public.student_progress enable row level security;
alter table public.feature_unlocks enable row level security;
alter table public.classrooms force row level security;
alter table public.student_profiles force row level security;
alter table public.student_progress force row level security;
alter table public.feature_unlocks force row level security;
create policy classrooms_deny_direct_access on public.classrooms for all to anon, authenticated using(false) with check(false);
create policy student_profiles_deny_direct_access on public.student_profiles for all to anon, authenticated using(false) with check(false);
create policy student_progress_deny_direct_access on public.student_progress for all to anon, authenticated using(false) with check(false);
create policy feature_unlocks_deny_direct_access on public.feature_unlocks for all to anon, authenticated using(false) with check(false);
revoke all on public.classrooms, public.student_profiles, public.student_progress, public.feature_unlocks from anon, authenticated;
grant usage on schema public to anon, authenticated;

create or replace function private.unlock_feature(sid uuid, feature text, reason text) returns void language plpgsql security definer set search_path=public,private as $$
begin insert into public.feature_unlocks(student_id,feature_key,unlock_reason) values(sid,feature,reason) on conflict(student_id,feature_key) do nothing; end $$;
create or replace function private.session_student(token text) returns uuid language sql security definer set search_path=public,private,extensions as $$
select student_id from private.student_sessions where token_hash=encode(digest(token,'sha256'),'hex') and expires_at>now() limit 1 $$;
create or replace function private.student_context(sid uuid) returns jsonb language sql security definer set search_path=public,private as $$
select jsonb_build_object('student_id',s.id,'display_name',s.display_name,'student_number',s.student_number,'first_login',s.first_login,
'account_status',s.account_status,'basic_job',s.basic_job,'cash',s.cash,'savings',s.savings,'housing_name',s.housing_name,
'growth_stage',p.growth_stage,'basic_job_tasks_completed',p.basic_job_tasks_completed,'jobs_completed',p.jobs_completed,
'first_salary_received',p.first_salary_received,'first_saving_completed',p.first_saving_completed,'saving_goal_reached',p.saving_goal_reached,
'donation_count',p.donation_count,'total_donation',p.total_donation,'feature_unlocks',coalesce((select jsonb_agg(feature_key order by unlocked_at) from public.feature_unlocks where student_id=s.id),'[]'::jsonb))
from public.student_profiles s join public.student_progress p on p.student_id=s.id where s.id=sid $$;

create or replace function public.fo_student_login(p_class_code text,p_display_name text,p_pin text) returns jsonb language plpgsql security definer set search_path=public,private,extensions as $$
declare c record; sid uuid; token text;
begin
 if p_pin !~ '^[0-9]{4}$' then return jsonb_build_object('ok',false,'message','학급코드, 이름, 숫자 4자리 PIN을 확인해 주세요.'); end if;
 delete from private.student_sessions where expires_at<=now();
 for c in select s.id,s.account_status,x.pin_hash,x.failed_attempts,x.locked_until from public.student_profiles s join public.classrooms r on r.id=s.class_id join private.student_credentials x on x.student_id=s.id where lower(r.class_code)=lower(trim(p_class_code)) and lower(s.display_name)=lower(trim(p_display_name)) loop
  if c.locked_until>now() then return jsonb_build_object('ok',false,'code','LOCKED','message','10분 후 다시 시도해 주세요.'); end if;
  if c.account_status<>'active' then return jsonb_build_object('ok',false,'code','DISABLED','message','선생님께 문의해 주세요.'); end if;
  if c.pin_hash=crypt(p_pin,c.pin_hash) then sid:=c.id; exit; end if;
  update private.student_credentials set failed_attempts=failed_attempts+1,last_failed_at=now(),locked_until=case when failed_attempts+1>=5 then now()+interval '10 minutes' end where student_id=c.id;
 end loop;
 if sid is null then return jsonb_build_object('ok',false,'message','학급코드, 이름 또는 PIN이 맞지 않아요.'); end if;
 update private.student_credentials set failed_attempts=0,locked_until=null where student_id=sid;
 token:=encode(gen_random_bytes(32),'hex'); insert into private.student_sessions values(encode(digest(token,'sha256'),'hex'),sid,now()+interval '8 hours',now());
 return jsonb_build_object('ok',true,'session_token',token,'student',private.student_context(sid));
end $$;
create or replace function public.fo_student_session(p_session_token text) returns jsonb language plpgsql security definer set search_path=public,private,extensions as $$
declare sid uuid:=private.session_student(p_session_token); begin if sid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if; return jsonb_build_object('ok',true,'student',private.student_context(sid)); end $$;
create or replace function public.fo_student_change_pin(p_session_token text,p_new_pin text) returns jsonb language plpgsql security definer set search_path=public,private,extensions as $$
declare sid uuid:=private.session_student(p_session_token); begin if sid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if; if p_new_pin !~ '^[0-9]{4}$' then return jsonb_build_object('ok',false,'message','PIN은 숫자 4자리로 만들어 주세요.'); end if; update private.student_credentials set pin_hash=crypt(p_new_pin,gen_salt('bf',10)),failed_attempts=0,locked_until=null where student_id=sid; update public.student_profiles set first_login=false,updated_at=now() where id=sid; return jsonb_build_object('ok',true,'student',private.student_context(sid)); end $$;
create or replace function public.fo_student_logout(p_session_token text) returns jsonb language plpgsql security definer set search_path=public,private,extensions as $$
begin delete from private.student_sessions where token_hash=encode(digest(p_session_token,'sha256'),'hex'); return jsonb_build_object('ok',true); end $$;
create or replace function public.fo_complete_basic_task(p_session_token text) returns jsonb language plpgsql security definer set search_path=public,private,extensions as $$
declare sid uuid:=private.session_student(p_session_token); n integer; paid boolean; begin if sid is null then return jsonb_build_object('ok',false); end if; select basic_job_tasks_completed,first_salary_received into n,paid from public.student_progress where student_id=sid for update; update public.student_progress set basic_job_tasks_completed=n+1,first_salary_received=true,growth_stage=greatest(growth_stage,case when n+1>=2 then 3 else 2 end),updated_at=now() where student_id=sid; if not paid then update public.student_profiles set cash=cash+800 where id=sid; perform private.unlock_feature(sid,'wallet','첫 월급'); perform private.unlock_feature(sid,'bank','첫 월급'); end if; if n+1>=2 then perform private.unlock_feature(sid,'job_board','기본업무 2회'); end if; if n+1>=4 then perform private.unlock_feature(sid,'competencies','업무 경험 4회'); end if; return jsonb_build_object('ok',true,'student',private.student_context(sid)); end $$;
create or replace function public.fo_student_save(p_session_token text,p_amount integer) returns jsonb language plpgsql security definer set search_path=public,private,extensions as $$
declare sid uuid:=private.session_student(p_session_token); saved integer; begin if sid is null then return jsonb_build_object('ok',false); end if; if p_amount<100 or p_amount>1000 or p_amount%100<>0 then return jsonb_build_object('ok',false,'message','100꿈 단위로 선택해 주세요.'); end if; if not exists(select 1 from public.feature_unlocks where student_id=sid and feature_key='bank') then return jsonb_build_object('ok',false,'code','FEATURE_LOCKED'); end if; update public.student_profiles set cash=cash-p_amount,savings=savings+p_amount where id=sid and cash>=p_amount returning savings into saved; if saved is null then return jsonb_build_object('ok',false,'message','현금이 부족해요.'); end if; update public.student_progress set first_saving_completed=true,saving_goal_reached=saving_goal_reached or saved>=3000 where student_id=sid; perform private.unlock_feature(sid,'housing','첫 저축'); if saved>=3000 then perform private.unlock_feature(sid,'my_room','저축 3,000꿈'); end if; return jsonb_build_object('ok',true,'student',private.student_context(sid)); end $$;

revoke all on function public.fo_student_login(text,text,text),public.fo_student_session(text),public.fo_student_change_pin(text,text),public.fo_student_logout(text),public.fo_complete_basic_task(text),public.fo_student_save(text,integer) from public;
revoke execute on function public.fo_student_login(text,text,text),public.fo_student_session(text),public.fo_student_change_pin(text,text),public.fo_student_logout(text),public.fo_complete_basic_task(text),public.fo_student_save(text,integer) from authenticated;
grant execute on function public.fo_student_login(text,text,text),public.fo_student_session(text),public.fo_student_change_pin(text,text),public.fo_student_logout(text),public.fo_complete_basic_task(text),public.fo_student_save(text,integer) to anon;
