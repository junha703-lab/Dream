begin;

create or replace function public.fo_student_submit_basic_task(
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

revoke all on function public.fo_student_submit_basic_task(text,uuid,text,text,uuid) from public,authenticated;
grant execute on function public.fo_student_submit_basic_task(text,uuid,text,text,uuid) to anon;

commit;
