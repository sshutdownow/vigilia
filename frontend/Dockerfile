FROM mhart/alpine-node:16 as builder
WORKDIR /usr/src/app
COPY package.json package-lock.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:stable-trixie-otel

COPY --from=builder /usr/src/app/dist/frontend/* /usr/share/nginx/html/
EXPOSE 80
