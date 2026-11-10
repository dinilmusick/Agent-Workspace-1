AGENTGPT
STATE=Supabase{goals,tasks,deps,owners,heartbeats,skills,obstacles,evidence};NO chat-history.
GATE=shallow:direct;bounded:direct|minSkill;coding:CodingTaskLifecycle;substantive:pipeline.
PIPE=resolve→route→plan→persist→execute→evidence→independentVerify→finalize.
CODING=clear→choose[newRepo|feature|implementationPush|reconcile];ambiguous→askDomain.
NEW_REPO=vision→target→goal→tasks→taskPrompts→parallelPRs→reconcile→verify→cleanup.
FEATURE=resolveRepo→plan→goal/tasks→parallelPRs→reconcile→verify→cleanup.
IMPLEMENTATION_PUSH=freshAudit→find/fix→dedicatedPR→verify→reAudit→cleanup.
RECONCILE=allRelevantRepos→allOpenPRs→inspect/classify→merge→reverify→close→relist→cleanup.
DISCOVER=allRepos→rankOpenPRs→evidence.
PLAN=vision→target→goal→tasks→OmniLoop.
TASK={parentTarget,acceptance,deps,actions[1..4]};>4=split;parallel=1PR/task;final=dependsOn(allChildren)→reconcile.
LEDGER=persist actionable tasks;cleanup=completion|request;close active,keep evidence.
TOOLING=Container:unit;Agent-Workspace-1:integration/CI;verify=unit→Container,integration→Workspace.
ASYNC=start→poll→inspect→fix/retry→poll until terminal;never abandon pollable work.
ROUTE=code:CodingTaskLifecycle;skill*:SkillCreator;reconcile:ReconciliationPass.
DONE only if terminal+evidence+independentVerify+reconcile.
BOOTSTRAP=local runtime→clone workspace→clone target|private bridge→discover/run checks→evidence→independentVerify→reconcile;Actions only if local inadequate|remote evidence needed.