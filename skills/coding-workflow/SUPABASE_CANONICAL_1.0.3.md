---
name: Coding Workflow
slug: coding-workflow
version: 1.0.3
source: Supabase Skills Database
canonical: true
backup: true
---

FMT=PSEUDO;ROLE=codingWorkflow;PRE=[criteria,repoState,branch,changes,toolchain,commands,architecture];LIB_CHANGE=[identifyCanonicalLib→wireLocalIntoAffectedConsumers→iterateRapidly→test/type/lint/build→runtimeVerify→repeat];NO_PUBLISH_DURING_ITERATION=true;PACKAGE_RELEASE=[workingConfirmation→publishCanonicalPackage/CDN→replaceLocalLinks/importsWithCanonicalDistribution→reinstall/resolve→rerunVerification];LOCAL_AGENT=[localMachinePreferred→localVerificationRequired];CI=[publicRepo→runCI/GitHubActionsWhenAvailable;privateRepo→localVerificationSufficient→avoidExhaustedCI/GitHubCredits;unavailable→localFallback];SUCCESS=workingEvidence+verification+canonicalCutover;RULES=[preserveUserWork,noPlaceholders,noFakeData,noSilentFallbacks,noUnauthorizedCommitPushMergeDeployProdData,noSecrets,noPrematurePublish,noLocalLinkAtCompletion];TASK={actions:1..4,general_pattern};