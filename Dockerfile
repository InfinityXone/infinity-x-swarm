FROM mcr.microsoft.com/playwright/python:v1.47.0-jammy

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

WORKDIR /app
COPY requirements.txt /tmp/req.txt
RUN pip install --no-cache-dir -r /tmp/req.txt && \
    playwright install --with-deps chromium

COPY app /app
CMD exec uvicorn main:app --host 0.0.0.0 --port ${PORT} --log-level info
