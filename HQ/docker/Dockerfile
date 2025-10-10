FROM python:3.11-slim

WORKDIR /app
COPY . /app

# Install dependencies
RUN pip install --no-cache-dir \
    fastapi \
    uvicorn \
    supabase \
    psycopg2-binary \
    google-cloud-pubsub \
    web3 \
    solana

# Cloud Run injects \$PORT automatically; just use it in CMD
CMD ["sh", "-c", "uvicorn api.main:app --host 0.0.0.0 --port \${PORT}"]
