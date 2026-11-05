---
name: Universal Task Router
slug: universal-task-router
version: 1.4.2
source: Supabase Skills Database
canonical: true
backup: true
---

FMT=PSEUDO;ROLE=universalRouter;IN=outcome+scope+constraints+permissions+deadline+repoVisibility+localAgent;ROUTE={coding:CodingRouter,skillCreate|skillUpdate|skillRevise|skillPublish:SkillCreator,other:closestActive};LOCAL_AGENT=[whenLocalMachineAvailable→preferRapidLocalIteration];LIBRARIES=[localWire→iterateUntilWorking→confirm→publishPackage/CDN→canonicalCutover];CI=[publicRepo→CI/GitHubActionsRecommended;privateRepo→localVerificationSufficientWhenCIExhausted];NO=prematurePublish|localLinkAtCompletion|unverifiedCompletion;STATE=Supabase;