# Runbook — Deploy to Cloud Run
## Preconditions
- Image in Artifact Registry
- SA roles: run.admin + iam.serviceAccountUser

## Steps
1) Update image/env payload.
2) Deploy (API or `gcloud run deploy SERVICE --image IMAGE --region REGION ...`)
3) Verify URL + `/healthz`; check logs.
4) Rollback via previous image or revision traffic split.

## Acceptance
- `200 OK` on `/healthz`
- <1% error rate for 10 minutes
