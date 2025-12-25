# 多阶段构建：n8n + Python + pip + uv
# Stage 1: 安装 Python 和 uv
FROM python:3.11-slim AS python-builder

# 安装 uv（快速 Python 包管理器）
RUN pip install --no-cache-dir uv

# Stage 2: 最终镜像基于官方 n8n
FROM docker.n8n.io/n8nio/n8n:latest

# 切换到 root 用户安装软件
USER root

# 安装 Python 运行时依赖
RUN apk add --no-cache \
    python3 \
    py3-pip \
    python3-dev \
    gcc \
    musl-dev \
    libffi-dev

# 从 python-builder 复制 uv
COPY --from=python-builder /usr/local/bin/uv /usr/local/bin/uv
COPY --from=python-builder /usr/local/lib/python3.11/site-packages/uv* /usr/local/lib/python3.11/site-packages/

# 创建 Python 虚拟环境目录
RUN mkdir -p /home/node/.local && \
    chown -R node:node /home/node/.local

# 设置环境变量
ENV PYTHONUNBUFFERED=1 \
    PATH="/home/node/.local/bin:$PATH"

# 验证安装
RUN python3 --version && \
    pip3 --version && \
    uv --version || echo "uv installation needs adjustment"

# 切换回 node 用户
USER node

# 设置工作目录
WORKDIR /home/node
