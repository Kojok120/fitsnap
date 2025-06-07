# cloudrun/Dockerfile
FROM node:20-slim

# FFmpeg インストール
RUN apt-get update && apt-get install -y \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 依存関係インストール
COPY package*.json ./
RUN npm install

# アプリケーションコード
COPY . .

# ポート設定
ENV PORT=8080

# 起動
CMD ["npm", "start"] 