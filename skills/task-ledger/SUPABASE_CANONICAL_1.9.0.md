---
name: "Task Ledger"
slug: task-ledger
version: 1.9.0
source: Supabase Skills Database
sourceId: 7
status: active
canonical: true
backup: true
---

FMT=PSEUDO;ROLE=canonicalGoalTaskLedger;IDENTITY={goal:name+goal_key+tags;UUID=internal};CREATE=goal_ledger_create_hierarchical(title,description,context,instructions,acceptance,tags,goalLoop,tasks,agent,owner,metadata);TASK={target,parentTargetImmutable,actions:1..4,general_pattern,acceptance,verification,loop,parameters,workerPrompt};ROUTINE=[overview→resume→claim→heartbeat→execute→iterate→submit→independentVerify→reconcile→finalize];CLAIM=atomic+FOR_UPDATE_SKIP_LOCKED;RECLAIM=heartbeat>=60m;VERIFY=independent;GOAL_PASS=[all_descendants_verified,all_criteria,evidence,reconciliation_pass];STATE=Supabase-canonical;RESUME=never_chat_history;EVENTS=appendOnly;DEPS=blocking/advisory;PARAMS=contract.required+properties→validated_result;CONSENT=propose_missing_task→explicit_yes→create;PROMOTE=explicit_goal_promotion→create_goal+full_recursive_decomposition;DECOMPOSE=[small|mid_size,independent,executable];PROMPT=each_task→persist_self_contained_worker_prompt[context+scope+inputs+outputs+acceptance+verification+deps+tools+general_pattern];FAIL=worker_must_persist[failed,reason,evidence,next_action];RECONCILE=mandatory_final_task→depends_on_all_required_children→inspect_results+evidence+deps;CODING=[parallel_children→one_PR_per_code_task→record_PR_in_task_metadata→final_reconcile];PR_RECONCILE=[merge_valid_PRs→resolve_conflicts→close_obsolete/rejected_PRs→NO_open_child_PRs→run_final_quality_gates];NO=[syntheticRoot,legacyCreateWithTasks,manualOwnership,completionWithoutEvidence,selfVerify,unreconciledGoal,openChildPROnCompletion];
