# FK Webstack - Frontend (lighttpd Web Server)
# Serves static HTML/JS webpage with API proxy
#
# Build: docker build -t fk-frontend:1.0 .
# Run:   docker run -p 8080:80 fk-frontend:1.0

FROM debian:bookworm-slim

# Install lighttpd web server (minimal, fast, lightweight) and curl for debugging
RUN apt-get update && apt-get install -y --no-install-recommends \
    lighttpd \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create web server directories
RUN mkdir -p /var/www/html /var/log/lighttpd /var/run/lighttpd

# Copy configuration (includes mod_proxy for API forwarding)
COPY lighttpd.conf /etc/lighttpd/lighttpd.conf

# Copy website
COPY index.html /var/www/html/index.html

# Expose web port
EXPOSE 80

# Health check for Kubernetes
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1

# Run lighttpd in foreground
# - -D: Don't daemonize (run in foreground for Docker)
# - -f: Use specific config file
# Lighttpd will proxy /api/ requests to fk-api:8000 (via mod_proxy in lighttpd.conf)
# Frontend's JavaScript calls http://localhost:8000/api/* which hits lighttpd proxy
CMD ["lighttpd", "-D", "-f", "/etc/lighttpd/lighttpd.conf"]
