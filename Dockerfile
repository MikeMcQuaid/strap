ARG RUBY_VERSION
FROM ruby:$RUBY_VERSION-alpine

RUN apk --update add build-base

RUN adduser strap --disabled-password --gecos ""
USER strap

WORKDIR /app
COPY . .

RUN script/bootstrap

HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f http://localhost:3000/ || exit 1

EXPOSE 3000
ENTRYPOINT ["script/server"]
