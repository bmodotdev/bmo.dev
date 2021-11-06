FROM nginx:latest

# Labels
ARG BUILD_DATE
ARG VERSION
ARG PUID
ARG PGID
LABEL build_version="nginx Version: ${VERSION} Build-date: ${BUILD_DATE}"

# System update
RUN echo "***** System update *****" && set -x \
    && apt-get update \
    && apt-get -y upgrade \
    && apt-get install -y inotify-tools \
    && apt-get clean

# Setup configurations
RUN echo "***** Setting up configuration ***" && set -x \
    && /bin/rm -v /etc/nginx/fastcgi_params /etc/nginx/scgi_params /etc/nginx/uwsgi_params /etc/nginx/nginx.conf /etc/nginx/conf.d/default.conf \
    && unlink /etc/nginx/modules \
    && mkdir -v /etc/nginx/modules \
    && chmod -v 0755 /etc/nginx/modules \
    && cp -av /usr/lib/nginx/modules/ngx_http_geoip_module.so /etc/nginx/modules \
    && /bin/rm -rv /usr/share/nginx/html

# Copy our configs
COPY --chown="${PUID}:${PGID}"  ./etc_nginx/.             /etc/nginx
COPY --chown="${PUID}:${PGID}"  ./etc_nginx_templates/.	  /etc/nginx/templates
COPY --chown="${PUID}:${PGID}"  ./usr_share_nginx_html/.  /usr/share/nginx/html
COPY --chown="${PUID}:${PGID}"  ./var_www/.               /var/www
COPY --chown="${PUID}:${PGID}"  ./docker-entrypoint.d/.   /docker-entrypoint.d

CMD ["nginx", "-c", "/etc/nginx/nginx.conf"]
