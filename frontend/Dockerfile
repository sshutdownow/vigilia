FROM mhart/alpine-node:16 as builder
WORKDIR /usr/src/app
COPY package.json package-lock.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:latest

# Install OpenTelemetry module
RUN apt-get update && \
    apt-get install -y nginx-module-otel && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/src/app/dist/frontend/* /usr/share/nginx/html/
EXPOSE 80
