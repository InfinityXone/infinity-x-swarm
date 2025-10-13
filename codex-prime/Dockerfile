FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt main.py ./
RUN pip install --no-cache-dir -r requirements.txt \
    && pip install fastapi uvicorn playwright httpx \
    && playwright install --with-deps chromium
ENV PORT=8080
EXPOSE 8080
CMD ["python", "main.py"]
