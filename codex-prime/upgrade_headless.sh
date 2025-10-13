#!/usr/bin/env bash
set -euo pipefail
PROJECT_ID="my-project-52092gpt-deployer"
SERVICE="codex-prime"
REGION="us-east1"
SA="codex-deployer@${PROJECT_ID}.iam.gserviceaccount.com"
IMG="us-east1-docker.pkg.dev/${PROJECT_ID}/${SERVICE}/${SERVICE}:latest"
ROOT_DIR="$HOME/infinity-x-swarm/${SERVICE}"
cd "$ROOT_DIR"

echo "🧱  Upgrading Codex Prime to full headless Playwright mode..."

# --- Replace Dockerfile ---
cat > Dockerfile <<'DOCKER'
FROM mcr.microsoft.com/playwright/python:v1.45.0-jammy
WORKDIR /app
COPY main.py requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
ENV PORT=8080
EXPOSE 8080
CMD ["python","main.py"]
DOCKER

# --- Add Playwright dependency if missing ---
grep -q playwright requirements.txt || echo "playwright==1.45.0" >> requirements.txt

# --- Add minimal headless browser route ---
cat >> main.py <<'PY'

from playwright.async_api import async_playwright

@app.post("/headless/fetch")
async def headless_fetch(request: Request):
    """Visit a URL headlessly, optionally fill a form, and return HTML title."""
    data = await request.json()
    url = data.get("url")
    if not url:
        return {"error": "missing url"}
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        await page.goto(url, wait_until="load")
        title = await page.title()
        await browser.close()
        return {"url": url, "title": title}
PY

echo "🚀  Building new image..."
gcloud builds submit --tag "$IMG"

echo "🌐  Deploying upgraded headless Codex Prime..."
gcloud run deploy "$SERVICE" \
  --image="$IMG" \
  --region="$REGION" \
  --service-account="$SA" \
  --set-secrets CODEX_API_KEY=CODEX_API_KEY:latest,CODEX_ROOT_ACCESS_CODE=CODEX_ROOT_ACCESS_CODE:latest,SUPABASE_URL=SUPABASE_URL:latest,SUPABASE_KEY=SUPABASE_KEY:latest,GROQ_API_KEY=GROQ_API_KEY:latest,VERCEL_TOKEN=VERCEL_TOKEN:latest,CODEX_GOOGLE_TOKEN=CODEX_GOOGLE_TOKEN:latest,LANGCHAIN_API_KEY=LANGCHAIN_API_KEY:latest \
  --cpu=2 --memory=2Gi --max-instances=3 \
  --ingress=all --allow-unauthenticated

echo "✅  Redeployment complete. Test with:"
echo "curl -X POST $(
  gcloud run services describe $SERVICE --region=$REGION --format='value(status.url)'
)/headless/fetch -H 'Content-Type: application/json' -d '{\"url\":\"https://example.com\"}'"
