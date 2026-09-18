FROM busybox:1.37.0-musl

WORKDIR /srv
COPY . ./
RUN test -f _site/index.html || \
    { echo "Run script/build before building the Docker image." >&2; exit 1; }

USER 65534:65534
EXPOSE 3000
HEALTHCHECK --interval=5m --timeout=3s \
  CMD wget -q -O /dev/null http://127.0.0.1:3000/ || exit 1

CMD ["httpd", "-f", "-p", "3000", "-h", "/srv/_site", "-c", "/srv/config/httpd.conf"]
