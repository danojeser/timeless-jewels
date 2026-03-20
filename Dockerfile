# ─── Stage 1: Compilar WASM (Go) ─────────────────────────────────────────────
FROM golang:1.22.5-alpine AS wasm-builder

WORKDIR /app

# Copiar módulos de Go primero para aprovechar el cache de capas
COPY go.mod go.sum ./
RUN go mod download

# Copiar el resto del código fuente
COPY . .

# Compilar el binario WASM
RUN GOOS=js GOARCH=wasm go build -ldflags="-s -w" -v -o frontend/static/calculator.wasm ./wasm


# ─── Stage 2: Compilar Frontend (Node/pnpm) ──────────────────────────────────
FROM node:22.17.0-alpine AS frontend-builder

# Habilitar corepack para usar pnpm
RUN corepack enable

WORKDIR /app/frontend

# Copiar el WASM compilado desde el stage anterior
COPY --from=wasm-builder /app/frontend/static/calculator.wasm ./static/calculator.wasm

# Copiar dependencias y configuración del frontend
COPY frontend/package.json frontend/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Copiar el código fuente del frontend
COPY frontend/ .

# Construir el sitio estático
RUN pnpm run build


# ─── Stage 3: Servidor nginx ─────────────────────────────────────────────────
FROM nginx:stable-alpine

# Añadir MIME type de WebAssembly a nivel global (bloque http)
RUN echo 'types { application/wasm wasm; }' >> /etc/nginx/mime.types

# Copiar el sitio estático construido
COPY --from=frontend-builder /app/frontend/build /usr/share/nginx/html

# Copiar configuración personalizada de nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
