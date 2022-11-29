FROM ruby:3.1.3

WORKDIR /app
COPY . .

# Apply security updates.
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home strap

USER strap

RUN script/bootstrap

HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f http://localhost:5000/ || exit 1

EXPOSE 5000
ENTRYPOINT ["script/server"]
