alter function private.student_context(uuid) rename to student_context_before_job_choice;

create function private.student_context(p_student_id uuid)
returns jsonb
language sql
security definer
set search_path = ''
as $$
select coalesce(private.student_context_before_job_choice(p_student_id),'{}'::jsonb)
  || jsonb_build_object(
    'needs_job_selection',coalesce((select s.basic_job='백수' from public.student_profiles s where s.id=p_student_id),true),
    'job_choices',coalesce((
      select jsonb_agg(jsonb_build_object(
        'code',j.code,
        'title',j.title,
        'description',j.description,
        'world',w.name,
        'tasks',coalesce((
          select jsonb_agg(jsonb_build_object('title',t.title,'description',t.description) order by t.sort_order,t.title)
          from public.basic_job_tasks t
          where t.job_code=j.code and t.active
        ),'[]'::jsonb)
      ) order by w.sort_order,j.title)
      from public.student_profiles s
      join public.class_job_settings cjs on cjs.class_id=s.class_id and cjs.active
      join public.jobs j on j.code=cjs.job_code and j.active
      join public.job_worlds w on w.key=j.world_key
      where s.id=p_student_id
    ),'[]'::jsonb)
  )
$$;

revoke all on function private.student_context(uuid) from public,anon,authenticated;

create or replace function public.fo_student_choose_job(p_session_token text,p_job_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  sid uuid:=private.session_student(p_session_token);
  cid uuid;
  current_job text;
  chosen_title text;
begin
  if sid is null then
    return jsonb_build_object('ok',false,'code','SESSION_EXPIRED','message','다시 로그인해 주세요.');
  end if;

  select s.class_id,s.basic_job into cid,current_job
  from public.student_profiles s
  where s.id=sid and s.account_status='active'
  for update;

  if current_job is distinct from '백수'
     or exists(select 1 from public.student_job_assignments a where a.student_id=sid and a.ended_at is null) then
    return jsonb_build_object('ok',false,'message','기본직업은 처음에 한 번만 직접 선택할 수 있어요.');
  end if;

  select j.title into chosen_title
  from public.jobs j
  join public.class_job_settings cjs on cjs.job_code=j.code and cjs.class_id=cid
  where j.code=p_job_code and j.active and cjs.active;

  if chosen_title is null then
    return jsonb_build_object('ok',false,'message','선택할 수 없는 직업이에요.');
  end if;

  insert into public.student_job_assignments(student_id,job_code) values(sid,p_job_code);
  update public.student_profiles set basic_job=chosen_title,updated_at=now() where id=sid;

  return jsonb_build_object(
    'ok',true,
    'message',chosen_title||' 직업으로 첫 항해를 시작해요!',
    'student',private.student_context(sid)
  );
end
$$;

revoke all on function public.fo_student_choose_job(text,text) from public,authenticated;
grant execute on function public.fo_student_choose_job(text,text) to anon;

create or replace function public.fo_teacher_create_student(
  p_session_token text,
  p_name text,
  p_number integer,
  p_job_code text,
  p_temp_pin text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  tid uuid:=private.teacher_from_session(p_session_token);
  cid uuid;
  sid uuid;
begin
  if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
  if length(trim(p_name))<2 or p_number<1 or p_temp_pin !~ '^[0-9]{4}$' then
    return jsonb_build_object('ok',false,'message','이름, 번호, 임시 PIN을 확인해 주세요.');
  end if;

  select class_id into cid from public.teacher_profiles where id=tid;
  insert into public.student_profiles(class_id,student_number,display_name,basic_job)
  values(cid,p_number,trim(p_name),'백수')
  returning id into sid;
  insert into public.student_progress(student_id) values(sid);
  insert into private.student_credentials(student_id,pin_hash)
  values(sid,extensions.crypt(p_temp_pin,extensions.gen_salt('bf',10)));
  insert into public.student_competencies(student_id,competency_key)
  select sid,key from public.competencies;

  return jsonb_build_object('ok',true,'message',trim(p_name)||' 학생 계정을 만들었어요. 첫 로그인 뒤 직업을 직접 선택합니다.');
exception
  when unique_violation then
    return jsonb_build_object('ok',false,'message','같은 번호 또는 이름의 학생이 이미 있어요.');
end
$$;

revoke all on function public.fo_teacher_create_student(text,text,integer,text,text) from public,authenticated;
grant execute on function public.fo_teacher_create_student(text,text,integer,text,text) to anon;

update public.student_job_assignments set ended_at=now() where ended_at is null;
update public.student_profiles set basic_job='백수',updated_at=now() where role='student';
delete from public.feature_unlocks;
