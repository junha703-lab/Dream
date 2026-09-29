begin;

insert into public.jobs(code,world_key,title,description,default_salary,active)
values ('librarian','info','사서','학급문고를 정리하고 친구에게 읽을 책을 추천합니다.',800,true)
on conflict (code) do update set
  world_key=excluded.world_key,
  title=excluded.title,
  description=excluded.description,
  default_salary=excluded.default_salary,
  active=excluded.active;

insert into public.class_job_settings(class_id,job_code,salary,active)
select id,'librarian',800,true from public.classrooms
on conflict (class_id,job_code) do update set
  salary=excluded.salary,
  active=excluded.active;

insert into public.basic_job_tasks(job_code,key,title,description,proof_mode,sort_order,active)
values
  ('librarian','librarian_library_management','학급문고 관리','책이 제자리에 있는지 살펴보고 빌리거나 돌려준 책을 정리해요.','checklist',1,true),
  ('librarian','librarian_book_recommendation','책 추천','친구가 읽을 만한 책을 고르고 추천하는 까닭을 짧게 소개해요.','result',2,true)
on conflict (key) do update set
  job_code=excluded.job_code,
  title=excluded.title,
  description=excluded.description,
  proof_mode=excluded.proof_mode,
  sort_order=excluded.sort_order,
  active=excluded.active;

update public.job_templates
set related_job_codes =
  case
    when 'librarian'=any(related_job_codes) then related_job_codes
    else array_append(related_job_codes,'librarian')
  end
where class_id is null and lower(title)=lower('학급문고 개선');

update public.job_templates
set
  description='학급문고에서 친구에게 소개하고 싶은 책을 골라 제목과 추천하는 까닭을 정리해요.',
  world_key='info',
  related_job_codes=array['librarian'],
  capacity=2,
  reward=240,
  duration_minutes=25,
  competency_rewards='{"knowledge_information":2,"aesthetic_emotion":1,"collaborative_communication":2,"community":1}'::jsonb,
  submission_method='추천할 책, 추천하는 까닭, 책 사진 또는 추천 카드',
  repeatable=true,
  active=true
where class_id is null and lower(title)=lower('친구에게 책 추천하기');

insert into public.job_templates(
  title,description,world_key,related_job_codes,capacity,reward,duration_minutes,
  competency_rewards,submission_method,repeatable,active,class_id
)
select
  '친구에게 책 추천하기',
  '학급문고에서 친구에게 소개하고 싶은 책을 골라 제목과 추천하는 까닭을 정리해요.',
  'info',
  array['librarian'],
  2,
  240,
  25,
  '{"knowledge_information":2,"aesthetic_emotion":1,"collaborative_communication":2,"community":1}'::jsonb,
  '추천할 책, 추천하는 까닭, 책 사진 또는 추천 카드',
  true,
  true,
  null
where not exists (
  select 1 from public.job_templates
  where class_id is null and lower(title)=lower('친구에게 책 추천하기')
);

commit;
