create index job_applications_evidence_reviewer_idx
  on public.job_applications(evidence_reviewed_by)
  where evidence_reviewed_by is not null;
