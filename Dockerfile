FROM ruby:2.7.4

WORKDIR /app
COPY . .

RUN script/bootstrap

HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f http://localhost:5000/ || exit 1

EXPOSE 5000
ENTRYPOINT ["script/server"]
