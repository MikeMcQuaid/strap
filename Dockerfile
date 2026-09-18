FROM busybox:1.37.0-musl

WORKDIR /srv
COPY public/ ./
COPY bin/strap.sh ./strap.sh
COPY bin/strap.sh ./strap.sh.txt
COPY httpd.conf /etc/httpd.conf

USER 65534:65534
EXPOSE 3000
HEALTHCHECK --interval=5m --timeout=3s \
  CMD wget -q -O /dev/null http://127.0.0.1:3000/up || exit 1

CMD ["httpd", "-f", "-p", "3000", "-h", "/srv", "-c", "/etc/httpd.conf"]
