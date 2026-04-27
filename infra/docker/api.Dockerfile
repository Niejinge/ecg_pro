FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY services/api/ /app/

RUN python -m pip install --upgrade pip && \
    python -m pip install -e .

EXPOSE 8000

CMD ["sh", "scripts/docker-entrypoint.sh"]
