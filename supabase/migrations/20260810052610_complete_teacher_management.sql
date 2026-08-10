begin;

create or replace function private.teacher_full_context(tid uuid) returns jsonb language sql security definer set search_path='' as $$
select coalesce(private.teacher_context(tid),'{}'::jsonb) || jsonb_build_object(
 'job_catalog',coalesce((select jsonb_agg(jsonb_build_object('code',j.code,'title',j.title,'world',w.name,'salary',coalesce(cjs.salary,j.default_salary)) order by w.sort_order,j.title) from public.teacher_profiles t join public.jobs j on j.active join public.job_worlds w on w.key=j.world_key left join public.class_job_settings cjs on cjs.class_id=t.class_id and cjs.job_code=j.code where t.id=tid),'[]'::jsonb),
 'templates',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'title',x.title,'world',w.name,'capacity',x.capacity,'reward',x.reward,'duration_minutes',x.duration_minutes) order by x.title) from public.job_templates x join public.job_worlds w on w.key=x.world_key where x.active),'[]'::jsonb),
 'seat_requests',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'student_name',s.display_name,'seat_name',seat.name,'seat_type',seat.seat_type,'move_cost',seat.move_cost,'status',r.status) order by r.requested_at) from public.seat_move_requests r join public.student_profiles s on s.id=r.student_id join public.seats seat on seat.id=r.seat_id join public.teacher_profiles t on t.class_id=s.class_id where t.id=tid and r.status='pending'),'[]'::jsonb)
)
$$;

create or replace function public.fo_teacher_session(p_session_token text) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=private.teacher_from_session(p_session_token); begin if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if; return jsonb_build_object('ok',true,'teacher',private.teacher_full_context(tid)); end $$;

create or replace function public.fo_teacher_create_student(p_session_token text,p_name text,p_number integer,p_job_code text,p_temp_pin text) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=private.teacher_from_session(p_session_token); cid uuid; sid uuid; job_title text;
begin
 if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 if length(trim(p_name))<2 or p_number<1 or p_temp_pin !~ '^[0-9]{4}$' then return jsonb_build_object('ok',false,'message','이름, 번호, 임시 PIN을 확인해 주세요.'); end if;
 select class_id into cid from public.teacher_profiles where id=tid;
 select title into job_title from public.jobs where code=p_job_code and active;
 if job_title is null then return jsonb_build_object('ok',false,'message','기본직업을 선택해 주세요.'); end if;
 insert into public.student_profiles(class_id,student_number,display_name,basic_job) values(cid,p_number,trim(p_name),job_title) returning id into sid;
 insert into public.student_progress(student_id) values(sid);
 insert into private.student_credentials(student_id,pin_hash) values(sid,extensions.crypt(p_temp_pin,extensions.gen_salt('bf',10)));
 insert into public.student_competencies(student_id,competency_key) select sid,key from public.competencies;
 insert into public.student_job_assignments(student_id,job_code) values(sid,p_job_code);
 return jsonb_build_object('ok',true,'message',trim(p_name)||' 학생 계정을 만들었어요.');
exception when unique_violation then return jsonb_build_object('ok',false,'message','같은 번호 또는 이름의 학생이 이미 있어요.');
end $$;

create or replace function public.fo_teacher_assign_job(p_session_token text,p_student_id uuid,p_job_code text,p_salary integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=private.teacher_from_session(p_session_token); cid uuid; job_title text; owns boolean;
begin
 if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 select class_id into cid from public.teacher_profiles where id=tid;
 select exists(select 1 from public.student_profiles where id=p_student_id and class_id=cid) into owns;
 select title into job_title from public.jobs where code=p_job_code and active;
 if not owns or job_title is null or p_salary<0 then return jsonb_build_object('ok',false,'message','학생, 직업, 월급을 확인해 주세요.'); end if;
 update public.student_job_assignments set ended_at=now() where student_id=p_student_id and ended_at is null;
 insert into public.student_job_assignments(student_id,job_code) values(p_student_id,p_job_code);
 update public.student_profiles set basic_job=job_title,updated_at=now() where id=p_student_id;
 insert into public.class_job_settings(class_id,job_code,salary) values(cid,p_job_code,p_salary) on conflict(class_id,job_code) do update set salary=excluded.salary;
 return jsonb_build_object('ok',true,'message','기본직업과 월급을 반영했어요.');
end $$;

create or replace function public.fo_teacher_open_template(p_session_token text,p_template_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=private.teacher_from_session(p_session_token); cid uuid; wid uuid;
begin
 if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 select class_id into cid from public.teacher_profiles where id=tid;
 select id into wid from public.class_weeks where class_id=cid and status='active';
 if wid is null then return jsonb_build_object('ok',false,'message','먼저 이번 주를 시작해 주세요.'); end if;
 insert into public.job_postings(week_id,template_id,title,description,world_key,related_job_codes,capacity,reward,duration_minutes,competency_rewards,submission_method)
 select wid,id,title,description,world_key,related_job_codes,capacity,reward,duration_minutes,competency_rewards,submission_method from public.job_templates where id=p_template_id and active
 and not exists(select 1 from public.job_postings where week_id=wid and template_id=p_template_id);
 if not found then return jsonb_build_object('ok',false,'message','이미 열렸거나 사용할 수 없는 템플릿이에요.'); end if;
 return jsonb_build_object('ok',true,'message','공고를 이번 주에 추가했어요.');
end $$;

create or replace function public.fo_teacher_review_seat(p_session_token text,p_request_id uuid,p_decision text) returns jsonb language plpgsql security definer set search_path='' as $$
declare tid uuid:=private.teacher_from_session(p_session_token); cid uuid; req record;
begin
 if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
 select class_id into cid from public.teacher_profiles where id=tid;
 select r.*,seat.move_cost,seat.student_id as occupant into req from public.seat_move_requests r join public.student_profiles s on s.id=r.student_id join public.seats seat on seat.id=r.seat_id where r.id=p_request_id and r.status='pending' and s.class_id=cid for update of r,seat;
 if req is null then return jsonb_build_object('ok',false,'message','이미 처리된 자리 신청이에요.'); end if;
 if p_decision='reject' then update public.seat_move_requests set status='rejected',reviewed_at=now() where id=req.id;
 elsif p_decision='approve' then
   if req.occupant is not null then return jsonb_build_object('ok',false,'message','그 사이 자리가 사용 중이 되었어요.'); end if;
   begin perform private.apply_transaction(req.student_id,'seat_move',-req.move_cost,0,'seat_move:'||req.id,'seat_move_request',req.id::text,tid::text); exception when others then return jsonb_build_object('ok',false,'message','학생의 현금이 부족해요.'); end;
   update public.seats set student_id=null where student_id=req.student_id;
   update public.seats set student_id=req.student_id where id=req.seat_id and student_id is null;
   update public.seat_move_requests set status='approved',reviewed_at=now() where id=req.id;
 else return jsonb_build_object('ok',false,'message','승인 또는 반려를 선택해 주세요.'); end if;
 return jsonb_build_object('ok',true,'message','자리 이동 신청을 처리했어요.');
end $$;

do $$ declare fn record; begin
 for fn in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('fo_teacher_create_student','fo_teacher_assign_job','fo_teacher_open_template','fo_teacher_review_seat') loop execute format('revoke all on function %s from public, authenticated',fn.signature); execute format('grant execute on function %s to anon',fn.signature); end loop;
end $$;
revoke all on function private.teacher_full_context(uuid) from public,anon,authenticated;
commit;
