---
name: Coding Router
slug: coding-router
version: 1.2.3
source: Supabase Skills Database
canonical: true
backup: true
---

FMT=PSEUDO;ROLE=codingRouter;IN→{intent,repo,layer,change,risk,evidence,repoVisibility,localAgent};SELECT=narrowestActivePublishedSkill+minimalSupport;LIB_CHANGE→CodingWorkflow(localIteration+localConsumerWiring);ORDER=Research/Architecture→Contract→LocalImplementation→DB/Security→LocalTesting→PackagePublish→CanonicalCutover→CI/Browser→Review→Docs;RULES=[sourceCanonical,reuseExisting,noUnrelatedEdits,noFakeBehavior,verifiedEvidence,preferLocalIteration,neverPublishToIterate];