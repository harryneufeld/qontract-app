# Build on an amd64 Linux builder; the resulting static assets are architecture independent,
# so multi-platform builds compile once on the builder's native platform.
FROM --platform=$BUILDPLATFORM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip xz-utils libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*
RUN test "$(uname -m)" = x86_64 \
    && git clone --depth 1 --branch 3.41.6 https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
RUN flutter config --no-analytics && flutter precache --web
WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
ARG QONTRACT_BASE_HREF=/
# The API URL is not compiled in: the runtime stage writes config.js from
# QONTRACT_API_BASE_URL at container start, so one image serves every environment.
# Fallback fonts are mirrored into the image so browsers never contact Google.
RUN dart deploy/validate_build.dart "$QONTRACT_BASE_HREF" \
    && flutter build web --release --base-href "$QONTRACT_BASE_HREF" \
    && dart deploy/mirror_fallback_fonts.dart build/web/main.dart.js build/web/assets/fonts/fallback \
    && mkdir -p /site"$QONTRACT_BASE_HREF" \
    && cp -a build/web/. /site"$QONTRACT_BASE_HREF"

FROM nginx:1.30-alpine AS runtime
ARG QONTRACT_BASE_HREF=/
ENV QONTRACT_BASE_HREF=$QONTRACT_BASE_HREF
RUN rm -f /usr/share/nginx/html/index.html /usr/share/nginx/html/50x.html
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --chmod=0755 deploy/docker-entrypoint.d/40-qontract-config.sh /docker-entrypoint.d/
COPY --from=build /site/ /usr/share/nginx/html/
# Each build places its fallback page at the selected root/subpath.
COPY --from=build /src/build/web/index.html /usr/share/nginx/html/_spa/index.html
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
