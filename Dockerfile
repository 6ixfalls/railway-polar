FROM alpine:3.21 AS core
RUN apk add --no-cache git
RUN git clone https://github.com/polarsource/polar.git --depth=1 --branch=main /tmp/source/

FROM --platform=$BUILDPLATFORM python:3.12-slim
LABEL org.opencontainers.image.source=https://github.com/polarsource/polar
LABEL org.opencontainers.image.description="Polar"
LABEL org.opencontainers.image.licenses=Apache-2.0
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ENV PYTHONUNBUFFERED=1
ENV UV_COMPILE_BYTECODE=1
ENV UV_NO_CACHE=1
ENV UV_NO_SYNC=1

WORKDIR /app/server

COPY --from=core /tmp/source/server/uv.lock /tmp/source/server/pyproject.toml .
RUN apt-get update && apt-get install -y build-essential redis libpq-dev curl \
    && uv sync --no-group dev --no-group backoffice --frozen \
    && apt-get autoremove -y build-essential

COPY --from=core /tmp/source/server/ /app/server/

ARG IPINFO_ACCESS_TOKEN
RUN mkdir /data && curl -fsSL https://ipinfo.io/data/free/country_asn.mmdb?token=$IPINFO_ACCESS_TOKEN -o /data/country_asn.mmdb
ENV POLAR_IP_GEOLOCATION_DATABASE_DIRECTORY_PATH=/data
ENV POLAR_IP_GEOLOCATION_DATABASE_NAME=country_asn.mmdb

ARG RELEASE_VERSION
ENV RELEASE_VERSION=${RELEASE_VERSION}

ENV POLAR_JWKS=/app/server/.jwks.json
ENTRYPOINT ["/bin/sh", "-c"]
CMD ["echo ${JWKS_JSON} > /app/server/.jwks.json && uv run uvicorn polar.app:app --host 0.0.0.0 --port 10000 --proxy-headers --forwarded-allow-ips '*'"]
