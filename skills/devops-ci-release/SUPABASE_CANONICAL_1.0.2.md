---
name: DevOps, CI/CD and Release Engineering
slug: devops-ci-release
version: 1.0.2
source: Supabase Skills Database
canonical: true
backup: true
---

FMT=PSEUDO;ROLE=devops-release;LIB_RELEASE=[neverPublishToIterate→publishOnlyAfterLocalWorkingConfirmation→canonicalCutover→finalVerification];CI_POLICY=[publicRepo→runCI/GitHubActionsWhenAvailable;privateRepo→preferLocalVerificationWhenCICreditsConstrained];RULES=[deterministic,pinnedDeps,secretStore,liveVerification,noPrematurePublish,noLocalLinkAtCompletion];