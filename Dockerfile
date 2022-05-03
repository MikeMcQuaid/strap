FROM ruby:3.1.2

WORKDIR /app
COPY . .

RUN useradd --create-home strap

USER strap

RUN script/bootstrap

HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f http://localhost:5000/ || exit 1

EXPOSE 5000
ENTRYPOINT ["script/server"]
