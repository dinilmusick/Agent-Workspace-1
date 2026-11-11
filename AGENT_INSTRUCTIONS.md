AGENTGPT
STATE=Supabase{goals,tasks,deps,owners,heartbeats,skills,obstacles,evidence};NO chat-history.
GATE=shallow:direct;bounded:direct|minSkill;coding:CodingTaskLifecycle;substantive:pipeline.
PIPE=resolve→route→plan→persist→execute→evidence→independentVerify→finalize.
CODING=clear→[newRepo|feature|implementationPush|reconcile];ambiguous→askDomain.
NEW_REPO=vision→target→goal→tasks→taskPrompts→parallelPRs→reconcile→verify→cleanup.
FEATURE=resolveRepo→plan→goal/tasks→parallelPRs→reconcile→verify→cleanup.
IMPLEMENTATION_PUSH=freshAudit→find/fix→dedicatedPR→verify→reAudit→cleanup.
RECONCILE=allRelevantRepos→allOpenPRs→inspect/classify→merge→reverify→close→relist→cleanup.
DISCOVER=allRepos→rankOpenPRs→evidence.
PLAN=vision→target→goal→tasks→OmniLoop.
TASK={parentTarget,acceptance,deps,actions[1..4]};>4=split;parallel=1PR/task;final=dependsOn(allChildren)→reconcile.
LEDGER=persist actionable tasks;cleanup=completion|request;close active,keep evidence.
TOOLING=local:unit;Workspace:integration/CI;verify=unit→local,integration→Workspace.
ASYNC=start→poll→inspect→fix/retry→poll;never abandon pollable work.
ROUTE=code:CodingTaskLifecycle;skill*:SkillCreator;reconcile:ReconciliationPass.
DONE=terminal+evidence+independentVerify+reconcile.
BOOTSTRAP=local→clone Workspace→clone target|private bridge→discover/run all checks/build scripts→evidence→independentVerify;Actions only if local unavailable/inadequate or remote evidence needed.
Goal phase prerequisites are database-enforced through `public.goal_dependencies`. A blocking dependency prevents every task in the dependent goal from entering `running` until the prerequisite goal and its complete descendant task tree are verified. Blocking cycles and cross-Vision edges are rejected; advisory edges never gate execution. Goal completion is also guarded. Never rely on agent prompts alone to enforce phase order.
