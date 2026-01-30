# Lighttpd installeren op een stabiele Debian base
FROM debian:bookworm-slim

# Installeer lighttpd
RUN apt-get update \
	&& apt-get install -y --no-install-recommends lighttpd ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

# Maak webroot en logs
RUN mkdir -p /var/www/html /var/log/lighttpd

# Kopieer custom config
COPY lighttpd.conf /etc/lighttpd/lighttpd.conf

# Kopieer de frontend naar de webroot
COPY index.html /var/www/html/index.html

# Expose poort 80 (standaard voor lighttpd)
EXPOSE 80

# Start lighttpd in foreground
CMD ["lighttpd", "-D", "-f", "/etc/lighttpd/lighttpd.conf"]
