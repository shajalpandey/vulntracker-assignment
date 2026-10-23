FROM python:3.11.17-slim@sha256:b7a9e5f6a93d6d4a31f129bbd4bdee69efccb6ded0fb230d78aafaf37af98377

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore

LABEL maintainer="Shajal Pandey <shajalp@gmail.com>"

WORKDIR /app

RUN groupadd --system --gid 10001 appuser \
    && useradd --system --uid 10001 --gid 10001 --no-create-home --shell /sbin/nologin appuser \
    && mkdir /data && chown appuser:appuser /data

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt \
    && pip uninstall --no-cache-dir -y setuptools wheel 

COPY app/ .

WORKDIR /data

USER 10001:10001

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["python", "-m", "uvicorn", "--app-dir", "/app", "main:app", "--host", "0.0.0.0", "--port", "8000"]

