# =====================================
# 统一使用 Alpine 平台
# =====================================

# 阶段 1: 准备 Python（Alpine 3.23 匹配 n8n 基础版本）
FROM alpine:3.23 AS python-layer
RUN apk add --no-cache \
    python3 \
    py3-pip

# 阶段 2: 准备 uv
FROM alpine:3.23 AS uv-layer
RUN apk add --no-cache curl && \
    curl -LsSf https://astral.sh/uv/install.sh | sh

# 阶段 3: 基于 n8n 官方镜像
FROM docker.n8n.io/n8nio/n8n:latest

USER root

# 复制 Python 完整环境（包括标准库）
COPY --from=python-layer /usr/bin/python3* /usr/bin/
COPY --from=python-layer /usr/bin/pip3* /usr/bin/
COPY --from=python-layer /usr/lib/python3.12 /usr/lib/python3.12
COPY --from=python-layer /usr/lib/libpython3.12.so* /usr/lib/

# 复制 uv
COPY --from=uv-layer /root/.local/bin/uv /usr/local/bin/uv
COPY --from=uv-layer /root/.local/bin/uvx /usr/local/bin/uvx

# 创建符号链接
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip

# 验证安装
RUN node --version && \
    npm --version && \
    python3 --version && \
    pip3 --version && \
    uv --version

# 复制依赖配置文件
COPY node-packages.txt /tmp/node-packages.txt

# 读取配置并安装全局 node_modules 依赖包
RUN if [ -s /tmp/node-packages.txt ]; then \
        grep -v '^#' /tmp/node-packages.txt | grep -v '^[[:space:]]*$' | while read -r pkg; do \
            if [ -n "$pkg" ]; then \
                echo "Installing: $pkg" && \
                npm install -g "$pkg"; \
            fi; \
        done; \
    fi && \
    # 清除 npm 缓存避免镜像过大
    npm cache clean --force && \
    rm -rf /tmp/* /root/.npm

USER node
WORKDIR /home/node

EXPOSE 5678

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD node -e "require('http').get('http://localhost:5678/healthz', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})" || exit 1
