ARG RUBY_VERSION
FROM ruby:$RUBY_VERSION

# Apply security updates.
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home strap
USER strap

WORKDIR /app
COPY . .

RUN script/bootstrap

HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f http://localhost:3000/ || exit 1

EXPOSE 3000
ENTRYPOINT ["script/server"]
