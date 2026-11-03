# rocketsmbd-docker

把上游 [glennswest/rocketsmbd](https://github.com/glennswest/rocketsmbd)（Rust 写的 io_uring SMB2/SMB3 服务端）的官方静态二进制，重新打包成 `scratch` 基础镜像，并靠 GitHub Actions 自动跟随上游版本更新。

## 镜像

- 基础镜像：`scratch`，镜像内只有 `/rocketsmbd` 一个静态 musl 二进制，无 shell、无 libc
- 架构：`linux/amd64`、`linux/arm64`（上游只发这两个的 `-musl` 产物，其它架构构建时直接失败）
- tag：跟随上游版本号 + `latest`

```
ghcr.io/ytx-zhang/rocketsmbd:1.4.1
ghcr.io/ytx-zhang/rocketsmbd:latest
```

想要 Docker Hub：仓库 Settings → Variables 加 `IMAGE_NAME=docker.io/<用户名>/rocketsmbd`，再配 `secrets.REGISTRY_USERNAME` / `secrets.REGISTRY_PASSWORD`。

## 自动更新

`.github/workflows/build-image.yml`

- 每天 02:00 UTC 查一次上游 `releases/latest`
- 该版本镜像已存在就跳过（可用 `force` 强制重建）
- 有新版本时用 buildx 同时构建 amd64 + arm64 并推送，`latest` 只指向最新 release
- 也可 `workflow_dispatch` 手动指定版本

构建阶段只下载官方 `rocketsmbd-{x86_64,aarch64}-linux-musl` 并用 `SHA256SUMS.txt` 校验，所以不需要 QEMU，几十秒出结果。

## 本地部署

仓库里带两份示例：`compose.example.yaml`（部署编排）和 `rocketsmbd.toml.example`（服务端配置）。实际使用的 `compose.yaml` / `rocketsmbd.toml` 在 `.gitignore` 里，不会上传。

```bash
cp compose.example.yaml compose.yaml
cp rocketsmbd.toml.example rocketsmbd.toml
# 改 rocketsmbd.toml 里的 server_name、用户名密码
docker compose up -d
docker compose logs -f
```

compose 用 host 网络直接监听宿主机 445，宿主机 `/mnt` 原样挂到容器 `/mnt`（与配置里 share 的 `path` 一致），配置文件单文件挂载到 `/etc/rocketsmbd/rocketsmbd.toml`。

校验配置（镜像里没有 shell，只能这样排障）：

```bash
docker compose run --rm rocketsmbd --check
```

## 注意

- 必须在 Linux 上跑：需要内核 ≥ 5.15 且开启 io_uring（推荐 ≥ 6.0），否则启动即退出
- Docker 默认 seccomp 不含 `io_uring_setup`，所以 compose 里挂 `seccomp-io_uring.json`（官方默认 profile + 只放行 `io_uring_setup`/`io_uring_enter`/`io_uring_register`）；该文件要和 `compose.yaml` 同目录
- scratch 镜像里没有 `/etc/passwd`，容器默认就是 root；root 自带 `CAP_NET_BIND_SERVICE` 和 `CAP_DAC_OVERRIDE`，所以 compose 里不用写 `cap_add`。要降权成非 root 才需要 `cap_add: [NET_BIND_SERVICE]` 并 chown 共享目录
- `core_pinning` 在容器里默认关掉，`--cpuset-cpus` 不连续时绑核会失败
- 只支持 SMB 2.0.2 ~ 3.1.1，不支持 SMB1/139 端口；1.4.x 只有 NTLMv2，无 Kerberos
- host 网络下宿主 445 必须空着（宿主 Samba/cifs 服务要先停），冲突时改配置里的 `listen`

## 本地手动构建

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  --build-arg ROCKETSMBD_VERSION=1.4.1 \
  -t rocketsmbd:1.4.1 -t rocketsmbd:latest --load .
```

国内网络可加 `--build-arg GITHUB_MIRROR=https://ghfast.top`（任意加速前缀）。
