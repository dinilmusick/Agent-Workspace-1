-- Publish the Coding Task Lifecycle contract so the deterministic routing matrix can admit it.
with inserted as (
  insert into public.skill_versions (
    skill_id, version, instructions, manifest, changelog, is_published, published_at
  )
  select
    s.id,
    '1.0.0',
    'FMT=PSEUDO;ROLE=codingLifecycle;TRIGGER=codingIntent→enterCodingIntake;OPTIONS=[newRepo,feature,implementationPush,reconciliation];ROUTE=newRepo|feature|implementationPush|reconciliation;NEW_REPO=brainstorm→vision→target→goal→tasks→parallelPRs→reconcile→verify→cleanup;FEATURE=resolveRepo→plan→goal→tasks→parallelPRs→reconcile→verify→cleanup;IMPLEMENTATION_PUSH=resolveRepo|feature→freshReanalysis→find→implement→newPR→verify→reAnalyze→cleanup;RECONCILIATION=resolveRepo→enumerateOpenPRs→inspect→classify→synthesize→merge→reverify→close→reEnumerate→cleanup;LEDGER=everyActionableTask→persistSupabase;TASK=target+acceptance+actions[1..4]+deps;PARALLEL=onePRPerTask;FINAL=dependsOn(allRequiredChildren)→reconcile→independentVerify;CLEANUP=completion|explicitCleanup→archive/closeActive+retainEvidence;NO_LOST_EVIDENCE=true;NO_STOP_BEFORE_TERMINAL=true;',
    '{"routing_modes":["newRepo","feature","implementationPush","reconciliation"],"deterministic":true}'::jsonb,
    'Publish the previously registered lifecycle skill as an executable routing version.',
    true,
    now()
  from public.skills s
  where s.id=45
  and not exists (
    select 1 from public.skill_versions v where v.skill_id=s.id and v.version='1.0.0'
  )
  returning id, skill_id
)
update public.skills s
set current_version_id = v.id, updated_at = now()
from public.skill_versions v
where s.id=45
  and v.skill_id=s.id
  and v.version='1.0.0'
  and v.is_published=true
  and s.current_version_id is null;
