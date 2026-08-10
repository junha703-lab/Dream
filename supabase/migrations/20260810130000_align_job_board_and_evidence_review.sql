alter table public.job_applications
  add column evidence_review_status text not null default 'not_reviewed'
    check (evidence_review_status in ('not_reviewed','reviewed','revision_requested')),
  add column evidence_feedback text check (evidence_feedback is null or char_length(evidence_feedback) <= 300),
  add column evidence_reviewed_at timestamptz,
  add column evidence_reviewed_by uuid references public.teacher_profiles(id) on delete set null;

create index job_applications_evidence_review_idx
  on public.job_applications(evidence_review_status, completed_at desc)
  where status = 'completed';

alter function private.student_context(uuid) rename to student_context_before_job_evidence_review;

create function private.student_context(p_student_id uuid)
returns jsonb
language sql
security definer
set search_path = ''
as $$
select coalesce(private.student_context_before_job_evidence_review(p_student_id),'{}'::jsonb)
  || jsonb_build_object(
    'applications',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',a.id,
        'posting_id',a.posting_id,
        'title',jp.title,
        'world',jw.name,
        'related_job_codes',jp.related_job_codes,
        'status',a.status,
        'summary',a.summary,
        'result_url',a.result_url,
        'fun_rating',a.fun_rating,
        'difficulty_rating',a.difficulty_rating,
        'completed_at',a.completed_at,
        'evidence_review_status',a.evidence_review_status,
        'evidence_feedback',a.evidence_feedback
      ) order by a.applied_at desc)
      from public.job_applications a
      join public.job_postings jp on jp.id=a.posting_id
      join public.job_worlds jw on jw.key=jp.world_key
      where a.student_id=p_student_id
    ),'[]'::jsonb)
  )
$$;

alter function private.teacher_context(uuid) rename to teacher_context_before_job_evidence_review;

create function private.teacher_context(p_teacher_id uuid)
returns jsonb
language sql
security definer
set search_path = ''
as $$
select coalesce(private.teacher_context_before_job_evidence_review(p_teacher_id),'{}'::jsonb)
  || jsonb_build_object(
    'job_submissions',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',a.id,
        'student_name',s.display_name,
        'student_number',s.student_number,
        'posting_title',jp.title,
        'status',a.status,
        'summary',a.summary,
        'result_url',a.result_url,
        'fun_rating',a.fun_rating,
        'difficulty_rating',a.difficulty_rating,
        'applied_at',a.applied_at,
        'completed_at',a.completed_at,
        'evidence_review_status',a.evidence_review_status,
        'evidence_feedback',a.evidence_feedback
      ) order by a.completed_at desc nulls last,a.applied_at desc)
      from public.teacher_profiles t
      join public.class_weeks cw on cw.class_id=t.class_id and cw.status='active'
      join public.job_postings jp on jp.week_id=cw.id
      join public.job_applications a on a.posting_id=jp.id
      join public.student_profiles s on s.id=a.student_id
      where t.id=p_teacher_id
    ),'[]'::jsonb)
  )
$$;

create function public.fo_teacher_review_job_evidence(
  p_session_token text,
  p_application_id uuid,
  p_decision text,
  p_feedback text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  tid uuid:=private.teacher_from_session(p_session_token);
  cid uuid;
  feedback_value text:=nullif(trim(coalesce(p_feedback,'')),'');
begin
  if tid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
  if p_decision not in ('reviewed','revision_requested') then
    return jsonb_build_object('ok',false,'message','확인 상태를 다시 선택해 주세요.');
  end if;
  if p_decision='revision_requested' and (feedback_value is null or char_length(feedback_value)<3) then
    return jsonb_build_object('ok',false,'message','학생이 고칠 수 있도록 보완 내용을 적어 주세요.');
  end if;

  select t.class_id into cid
  from public.teacher_profiles t
  where t.id=tid and t.account_status='active';

  if not exists(
    select 1
    from public.job_applications a
    join public.job_postings jp on jp.id=a.posting_id
    join public.class_weeks cw on cw.id=jp.week_id
    where a.id=p_application_id and cw.class_id=cid and a.status='completed'
  ) then
    return jsonb_build_object('ok',false,'message','확인할 수 없는 공고 기록이에요.');
  end if;

  update public.job_applications
  set evidence_review_status=p_decision,
      evidence_feedback=case when p_decision='revision_requested' then feedback_value else null end,
      evidence_reviewed_at=now(),
      evidence_reviewed_by=tid
  where id=p_application_id;

  return jsonb_build_object(
    'ok',true,
    'message',case when p_decision='revision_requested' then '학생에게 보완 요청을 표시했어요.' else '제출 증거를 확인했어요.' end
  );
end
$$;

create function public.fo_student_resubmit_job_evidence(
  p_session_token text,
  p_application_id uuid,
  p_summary text,
  p_result_url text,
  p_fun integer,
  p_difficulty integer
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  sid uuid:=private.session_student(p_session_token);
  result_value text:=nullif(trim(coalesce(p_result_url,'')),'');
begin
  if sid is null then return jsonb_build_object('ok',false,'code','SESSION_EXPIRED'); end if;
  if char_length(trim(coalesce(p_summary,'')))<5 or p_fun not between 1 and 5 or p_difficulty not between 1 and 5 then
    return jsonb_build_object('ok',false,'message','한 일과 느낌을 조금 더 기록해 주세요.');
  end if;
  if result_value is not null and not (
    result_value~'^https?://.{1,990}$'
    or (char_length(result_value)<=1000000 and result_value~'^data:image/(jpeg|png|webp);base64,')
  ) then
    return jsonb_build_object('ok',false,'message','사진은 750KB 이하 JPG·PNG·WEBP 파일 또는 안전한 링크만 사용할 수 있어요.');
  end if;

  update public.job_applications
  set summary=trim(p_summary),
      result_url=result_value,
      fun_rating=p_fun,
      difficulty_rating=p_difficulty,
      evidence_review_status='not_reviewed',
      evidence_feedback=null,
      evidence_reviewed_at=null,
      evidence_reviewed_by=null
  where id=p_application_id
    and student_id=sid
    and status='completed'
    and evidence_review_status='revision_requested';

  if not found then return jsonb_build_object('ok',false,'message','다시 제출할 수 없는 공고 기록이에요.'); end if;
  return jsonb_build_object('ok',true,'message','보완한 활동 증거를 다시 제출했어요.','student',private.student_context(sid));
end
$$;

revoke all on function private.student_context_before_job_evidence_review(uuid),private.student_context(uuid),private.teacher_context_before_job_evidence_review(uuid),private.teacher_context(uuid) from public,anon,authenticated;
revoke all on function public.fo_teacher_review_job_evidence(text,uuid,text,text),public.fo_student_resubmit_job_evidence(text,uuid,text,text,integer,integer) from public,authenticated;
grant execute on function public.fo_teacher_review_job_evidence(text,uuid,text,text),public.fo_student_resubmit_job_evidence(text,uuid,text,text,integer,integer) to anon;
