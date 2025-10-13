# Quickstart
1) Keep this under `docs/org/` in your repo.
2) Fill `01_System_Overview.md` and `02_Locations_and_Keys_Map.md`.
3) Load `03_Environment_Configs/.env.example` into vault/Secret Manager → generate real envs.
4) Run `scripts/gcp_inventory.sh` to populate inventories.
5) Use `05_Agents/agent_handoff_template.md` for assignments; update `agent_roster.csv`.
6) Run `09_Checklists/preflight_checklist.md` before deploys; `release_checklist.md` after.
