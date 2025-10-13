# Locations & Keys Map (Source of Truth)
> Store identifiers, not raw secrets. Reference Secret Manager versions.

## Cloud Run
- codex-prime — region: us-east1 — image: us-east1-docker.pkg.dev/... — URL: https://...
- gpt-gateway — region: us-west1 — image: us-west1-docker.pkg.dev/... — URL: https://...
- satellite-01 — region: us-east1 — image: ... — URL: https://...

## Buckets
- gs://infinity-agent-artifacts
- gs://infinity-swarm-system
- gs://my-project-52092gpt-deployer_cloudbuild
- gs://run-sources-my-project-52092gpt-deployer-us-west1

## Secrets (names + version numbers only)
- projects/.../secrets/supabase-service-role-key (vN)
- projects/.../secrets/groq-api-key (vN)
- projects/.../secrets/gateway-jwt-secret (vN)

## GitHub
- org: InfinityXone
- repos: genesis, infinity-x-swarm, codex-prime

## Vercel
- project: Infinity X Swarm Console — URL: https://infinity-x-one.vercel.app
