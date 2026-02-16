FROM debian:bookworm-slim AS builder

ARG ZIG_VERSION=0.16.0-dev.2535+b5bd49460

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl ca-certificates xz-utils git libsqlite3-dev && \
    rm -rf /var/lib/apt/lists/*

RUN ARCH=$(dpkg --print-architecture) && \
    case "$ARCH" in amd64) ZIG_ARCH=x86_64;; arm64) ZIG_ARCH=aarch64;; esac && \
    curl -L "https://ziglang.org/builds/zig-linux-${ZIG_ARCH}-${ZIG_VERSION}.tar.xz" -o /tmp/zig.tar.xz && \
    mkdir -p /opt/zig && \
    tar -xJf /tmp/zig.tar.xz -C /opt/zig --strip-components=1 && \
    rm /tmp/zig.tar.xz

ENV PATH="/opt/zig:${PATH}"

WORKDIR /build

# Clone public dependencies
RUN git clone --depth 1 https://github.com/seemsindie/zzz.git ../zzz && \
    git clone --depth 1 https://github.com/seemsindie/zzz_db.git ../zzz_db && \
    git clone --depth 1 https://github.com/seemsindie/zzz_jobs.git ../zzz_jobs

COPY . .
RUN zig build -Doptimize=ReleaseSafe

FROM debian:bookworm-slim
RUN apt-get update && \
    apt-get install -y --no-install-recommends libsqlite3-0 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/zig-out/bin/example_app /usr/local/bin/
COPY --from=builder /build/public /app/public

WORKDIR /app
EXPOSE 9000
CMD ["example_app"]
