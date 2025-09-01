ARG RUBY_VERSION=3
FROM ruby:$RUBY_VERSION-slim AS base
WORKDIR /app

# Common environment for all stages
ENV BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_WITHOUT="development,test" \
    RAILS_ENV="production" \
    RAILS_LOG_TO_STDOUT="1" \
    RAILS_SERVE_STATIC_FILES="1"

# Build stage with build dependencies
FROM base AS build

# Install build dependencies
RUN apt-get update -q && \
    apt-get install -y --no-install-recommends \
    libyaml-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy Bundler files
COPY .ruby-version Gemfile Gemfile.lock ./

# Run Bundler
RUN bundle install --retry 3

# Copy application code
COPY . .

# Exclude Sorbet RBI files and setup clean Bootsnap cache
RUN rm -rf sorbet/rbi tmp/bootsnap* && \
    bin/bootsnap precompile app/

# Final runtime stage
FROM base AS runtime

# Setup curl for healthcheck
RUN apt-get update -q && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Copy bundled gems from build stage
COPY --from=build /usr/local/bundle /usr/local/bundle

# Copy application code
COPY --from=build /app /app

# Create dedicated user
RUN groupadd -r strap && useradd -r -g strap strap
RUN chown -R strap:strap /app
USER strap

# Setup healthcheck route
HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f "http://localhost:3000/up" || exit 1

# Expose port
EXPOSE 3000

CMD ["bin/rails", "server"]
