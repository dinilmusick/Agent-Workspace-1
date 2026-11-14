AGENTGPT
STATE=Supabase{universes,systems,goals,tasks,deps,owners,heartbeats,skills,obstacles,evidence};NO chat-history.
UNIVERSE=firstClass bounded context; each system belongs to exactly one universe.
SYSTEM=firstClass recursive entity; subsystem is only a frame of reference; system={identity,universe,parameters,memory,function,children,relationships,state}.
SYSTEM_CONTEXT=resolve universe+system+ancestors+relevant memories/functions/children before planning.
WORMHOLE=cross-universe linked system; clone=snapshot with no link; wormhole sync must respect explicit sync scope/mode.
GATE=shallow:direct;bounded:direct|minSkill;coding:CodingTaskLifecycle;substantive:pipeline.
PIPE=resolve→route→plan→persist→execute→evidence→verify→finalize.
CODING=clear→[newRepo|feature|implementationPush|reconcile];ambiguous→askDomain.
CODING_FLOW=vision→target→goal→tasks→parallelPRs→reconcile→verify→cleanup.
RECONCILE=allRepos→allOpenPRs→inspect→merge→reverify→close→relist→cleanup.
DISCOVER=allRepos→rankOpenPRs.
TASK={parentTarget,system,acceptance,deps,actions[1..4]};>4=split;parallel=1PR/task;final=dependsOn(children)→reconcile.
GOAL_DEPS=goal_dependencies(dependent,prerequisite,blocking|advisory);blocking gates starts+completion;DB rejects cycles/cross-Vision.
LEDGER=persist actionable work;atomic claims;heartbeat;independentVerify;evidence.
TOOLING=local:unit;Workspace:integration/CI;verify=unit→local,integration→Workspace.
ASYNC=start→poll→inspect→fix/retry→poll;never abandon pollable work.
ROUTE=code:CodingTaskLifecycle;skill*:SkillCreator;reconcile:ReconciliationPass.
DONE=terminal+evidence+independentVerify+reconcile.
BOOTSTRAP=local→Workspace→target|private bridge→all checks;remote actions only if needed.