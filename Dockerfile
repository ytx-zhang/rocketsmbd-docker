# syntax=docker/dockerfile:1

# 上游版本，CI 通过 --build-arg 覆盖
ARG ROCKETSMBD_VERSION=1.4.1

# ---------- 阶段 1：取官方发布的静态 musl 二进制 ----------
# 只下载、不执行，所以不需要 QEMU 就能交叉出 arm64 镜像
FROM --platform=$BUILDPLATFORM alpine:3.22 AS fetch

ARG ROCKETSMBD_VERSION
ARG TARGETARCH
# 可选 GitHub 加速前缀，例如 --build-arg GITHUB_MIRROR=https://ghfast.top
ARG GITHUB_MIRROR=""

# 下载/校验逻辑放在脚本里，避免 Dockerfile 对 $ 的转义把 shell 变量变成字面量
ENV ROCKETSMBD_VERSION=${ROCKETSMBD_VERSION} \
    TARGETARCH=${TARGETARCH} \
    GITHUB_MIRROR=${GITHUB_MIRROR}

COPY scripts/fetch.sh /fetch.sh
RUN sh /fetch.sh

# ---------- 阶段 2：scratch 空镜像 ----------
FROM scratch

ARG ROCKETSMBD_VERSION
LABEL org.opencontainers.image.title="rocketsmbd" \
      org.opencontainers.image.description="SMB2/SMB3 file server on io_uring, static musl binary" \
      org.opencontainers.image.version="${ROCKETSMBD_VERSION}" \
      org.opencontainers.image.url="https://github.com/glennswest/rocketsmbd" \
      org.opencontainers.image.source="https://github.com/glennswest/rocketsmbd" \
      org.opencontainers.image.licenses="MIT"

COPY --from=fetch /out/rocketsmbd /rocketsmbd

# 445 需要 root 或 CAP_NET_BIND_SERVICE
EXPOSE 445
ENTRYPOINT ["/rocketsmbd", "--config", "/etc/rocketsmbd/rocketsmbd.toml"]
