FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends stockfish \
    && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir flask==3.1.1 gunicorn==23.0.0 python-chess==1.999

WORKDIR /app
COPY app.py /app/app.py
EXPOSE 8080
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "--threads", "4", "--timeout", "45", "app:app"]
