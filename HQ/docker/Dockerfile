FROM python:3.11-slim
WORKDIR /app
COPY ../.. /app
RUN pip install --no-cache-dir fastapi uvicorn supabase psycopg2-binary google-cloud-pubsub web3 solana
CMD ["uvicorn","api.main:app","--host","0.0.0.0","--port","8080"]
