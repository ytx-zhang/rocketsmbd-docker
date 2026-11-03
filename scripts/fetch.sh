#!/bin/sh
# 在 alpine 构建阶段执行：下载上游对应架构的静态 musl 二进制并做 SHA256 校验
set -eu

: "${ROCKETSMBD_VERSION:?ROCKETSMBD_VERSION is required}"
: "${TARGETARCH:?TARGETARCH is required}"

case "$TARGETARCH" in
  amd64) asset_arch=x86_64 ;;
  arm64) asset_arch=aarch64 ;;
  *)
    echo "unsupported TARGETARCH=$TARGETARCH (upstream only ships x86_64/aarch64)" >&2
    exit 1
    ;;
esac

asset="rocketsmbd-${asset_arch}-linux-musl"
base="${GITHUB_MIRROR:-}https://github.com/glennswest/rocketsmbd/releases/download/v${ROCKETSMBD_VERSION}"

cd /tmp
echo "downloading ${asset} from v${ROCKETSMBD_VERSION}"
wget -q -O "$asset" "${base}/${asset}"
wget -q -O SHA256SUMS.txt "${base}/SHA256SUMS.txt"

if ! grep -E "[[:space:]]${asset}\$" SHA256SUMS.txt > checksum.txt; then
    echo "no SHA256SUMS entry for ${asset}" >&2
    cat SHA256SUMS.txt >&2
    exit 1
fi
sha256sum -c checksum.txt

mkdir -p /out
install -m 0755 "$asset" /out/rocketsmbd
echo "ok: ${asset} -> /out/rocketsmbd"
