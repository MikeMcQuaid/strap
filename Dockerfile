ARG RUBY_VERSION=3
FROM ruby:$RUBY_VERSION-slim AS base

WORKDIR /app

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
RUN bundle config --global 'frozen' '1' && \
    bundle config --global 'without' 'development test' && \
    bundle install

# Copy application code
COPY . .

# Exclude sorbet rbi files and bootsnap cache from build
RUN rm -rf sorbet/rbi tmp/bootsnap*

# Precompile bootsnap cache
RUN bin/bootsnap precompile app/

# Final runtime stage
FROM base AS runtime

# Copy bundled gems from build stage
COPY --from=build /usr/local/bundle /usr/local/bundle

# Copy application code
COPY --from=build /app /app

# Create dedicated user
RUN groupadd -r strap && useradd -r -g strap strap
RUN chown -R strap:strap /app
USER strap

# Setup production environment
ENV RAILS_ENV=production \
  PORT="3000"

# Setup healthcheck route
HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f http://localhost:3000/up || exit 1

# Expose port
EXPOSE 3000

CMD ["bin/rails", "server"]
