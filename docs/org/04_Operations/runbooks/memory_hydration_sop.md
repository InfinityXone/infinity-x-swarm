# SOP — Memory Hydration
- Trigger: new snapshot, weekly rotation, or stale index.
- Sources: GCS (infinity-agent-artifacts), GitHub, Drive.
- Chunk: 512–1024 tokens; metadata: repo, SHA, path.
- Validate dims/provider; backfill missing.
- Audit snapshot_id, counts, checksum.
