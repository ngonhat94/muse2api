# Optional sidecar, never started by backend CI or the production rollout.
FROM node:26-bookworm-slim@sha256:5df79989ed685e09f0a98019db4cebfb22fb9df1a53c0161664a011f7ff6b0f1 AS build
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl python3 make g++ pkg-config libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/bgutil
RUN curl --fail --location --proto '=https' --tlsv1.2 https://api.github.com/repos/Brainicism/bgutil-ytdlp-pot-provider/tarball/26475e9d3665b972c4aeb83b4dbaafcf64b88438 -o /tmp/source.tar.gz \
 && echo 'c9a45ba23758d30b93e09650103bf340fb2a2c295039d47d064e8f0140f73f59  /tmp/source.tar.gz' | sha256sum -c - \
 && tar xzf /tmp/source.tar.gz --strip-components=1 && rm /tmp/source.tar.gz
WORKDIR /opt/bgutil/server
RUN npm ci --no-audit --no-fund && ./node_modules/.bin/tsc && npm prune --omit=dev --no-audit --no-fund

FROM node:26-bookworm-slim@sha256:5df79989ed685e09f0a98019db4cebfb22fb9df1a53c0161664a011f7ff6b0f1
RUN apt-get update && apt-get install -y --no-install-recommends python3 libcairo2 libpango-1.0-0 libpangocairo-1.0-0 libjpeg62-turbo libgif7 librsvg2-2 ca-certificates && rm -rf /var/lib/apt/lists/*
# Includes upstream GPL source, lockfile and license for the exact build.
COPY --from=build /opt/bgutil /opt/bgutil
WORKDIR /opt/muse
COPY --chown=1000:1000 pot_broker.py ./
COPY --chown=1000:1000 deploy/pot-provider/server.py deploy/pot-provider/mint.mjs ./
COPY --chown=1000:1000 tools/check_pot_sidecar.py ./check_offline.py
COPY --chown=1000:1000 tests/pot_mint_contract.mjs ./mint_contract.mjs
ENV PYTHONDONTWRITEBYTECODE=1
USER 1000:1000
ENTRYPOINT ["python3","/opt/muse/server.py"]
