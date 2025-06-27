# 从 Node.js 20 LTS 开始
FROM node:20

# 安装 Docker CLI（支持 DinD）
RUN apt-get update && \
    apt-get install -y docker.io && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 验证 Node.js 和 npm
RUN node --version && npm --version

# 确保 npm 全局路径正确
ENV PATH=/usr/local/bin:$PATH
ENV NPM_CONFIG_PREFIX=/usr/local

RUN npm install -g @anthropic-ai/claude-code

# 设置工作目录
WORKDIR /app

# 默认命令：保持容器运行
CMD ["tail", "-f", "/dev/null"]
