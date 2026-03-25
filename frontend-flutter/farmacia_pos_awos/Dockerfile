# Build stage
FROM debian:bookworm AS builder

# Install Flutter dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Download and install Flutter
RUN git clone https://github.com/flutter/flutter.git /flutter && \
    cd /flutter && \
    git checkout stable

ENV PATH="/flutter/bin:${PATH}"

# Enable web platform
RUN flutter config --enable-web

# Clone the app and build
WORKDIR /app
COPY . .

# Get dependencies
RUN flutter pub get

# Build web release with production endpoints
# Note: Update these URLs with your actual Railway service URLs
ARG NODE_API_URL=https://your-node.up.railway.app
ARG PYTHON_API_URL=https://your-python.up.railway.app

RUN flutter build web --release \
    --dart-define=NODE_API_URL=${NODE_API_URL} \
    --dart-define=PYTHON_API_URL=${PYTHON_API_URL}

# Serve stage
FROM nginx:alpine

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built web app
COPY --from=builder /app/build/web /usr/share/nginx/html

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
