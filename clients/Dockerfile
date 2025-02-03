# syntax=docker.io/docker/dockerfile:1

ARG NEXT_PUBLIC_API_URL NEXT_PUBLIC_FRONTEND_BASE_URL NEXT_PUBLIC_STRIPE_KEY NEXT_PUBLIC_GITHUB_APP_NAMESPACE NEXT_PUBLIC_APPLE_DOMAIN_ASSOCIATION

FROM alpine:3.21 AS core
RUN apk add --no-cache git
RUN git clone https://github.com/polarsource/polar.git --depth=1 --branch=main /tmp/source/
WORKDIR /tmp/source
ADD ./standalone.diff .
RUN git apply --ignore-space-change --ignore-whitespace standalone.diff

FROM node:18-alpine AS base

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=core /tmp/source/clients/ .

# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
# Uncomment the following line in case you want to disable telemetry during the build.
ENV NEXT_TELEMETRY_DISABLED=1

# Deps
RUN npm install -g corepack@latest && \
  corepack enable pnpm && \
  pnpm i --frozen-lockfile

RUN \
  if [ -f yarn.lock ]; then yarn run build; \
  elif [ -f package-lock.json ]; then npm run build; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm run build; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
# Uncomment the following line in case you want to disable telemetry during runtime.
# ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/apps/web/public ./public

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/static ./apps/web/.next/static
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/public ./apps/web/public

USER nextjs

EXPOSE 3000

ENV PORT=3000

# server.js is created by next build from the standalone output
# https://nextjs.org/docs/pages/api-reference/config/next-config-js/output
ENV HOSTNAME="0.0.0.0"
CMD ["node", "apps/web/server.js"]
