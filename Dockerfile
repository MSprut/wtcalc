# syntax=docker/dockerfile:1

# ===== Builder stage: install deps, build JS, precompile assets =====
ARG RUBY_VERSION=3.3.9
FROM ruby:${RUBY_VERSION} AS builder

# OS deps for building gems and assets
RUN apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends     build-essential git curl pkg-config libpq-dev libvips     nodejs npm ca-certificates &&     rm -rf /var/lib/apt/lists/*

# Yarn via corepack
RUN corepack enable && corepack prepare yarn@1.22.22 --activate

WORKDIR /rails

# Gem cache
COPY Gemfile Gemfile.lock ./
RUN bundle config set deployment true  && bundle config set without 'development test'  && bundle install --jobs 4

# JS deps cache
COPY package.json yarn.lock ./
RUN if [ -f package.json ]; then yarn install --frozen-lockfile || yarn install; fi

# App source
COPY . .

ENV RAILS_ENV=production     NODE_ENV=production

# Build JS (jsbundling-rails) then precompile assets
RUN mkdir -p app/assets/builds &&     if yarn run | grep -qE '^\s*build\s'; then yarn build; fi &&     if yarn run | grep -qE '^\s*build:css\s'; then yarn build:css; fi &&     SECRET_KEY_BASE=dummy bundle exec rails assets:precompile

# ===== Runtime stage: minimal image with compiled app =====
FROM ruby:${RUBY_VERSION}-slim AS app

# Runtime deps only
RUN apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends     libvips postgresql-client &&     rm -rf /var/lib/apt/lists/*

WORKDIR /rails

ENV RAILS_ENV=production     RACK_ENV=production     RAILS_LOG_TO_STDOUT=1     RAILS_SERVE_STATIC_FILES=1

# Copy compiled app from builder
COPY --from=builder /rails /rails

# Non-root user
RUN groupadd --system rails && useradd --system --gid rails rails && chown -R rails:rails /rails
USER rails

EXPOSE 3000
CMD ["bash", "-lc", "bundle exec rails db:prepare && bundle exec puma -C config/puma.rb"]






# OLD
# # syntax = docker/dockerfile:1

# # This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# # docker build -t my-app .
# # docker run -d -p 80:80 -p 443:443 --name my-app -e RAILS_MASTER_KEY=<value from config/master.key> my-app

# # Make sure RUBY_VERSION matches the Ruby version in .ruby-version
# ARG RUBY_VERSION=3.3.9
# FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# # Rails app lives here
# WORKDIR /rails

# # Install base packages
# RUN apt-get update -qq && \
#     apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client && \
#     rm -rf /var/lib/apt/lists /var/cache/apt/archives

# # Set production environment
# ENV RAILS_ENV="production" \
#     BUNDLE_DEPLOYMENT="1" \
#     BUNDLE_PATH="/usr/local/bundle" \
#     BUNDLE_WITHOUT="development"

# # Throw-away build stage to reduce size of final image
# FROM base AS build

# # Install packages needed to build gems and node modules
# RUN apt-get update -qq && \
#     apt-get install --no-install-recommends -y build-essential git libpq-dev node-gyp pkg-config python-is-python3 && \
#     rm -rf /var/lib/apt/lists /var/cache/apt/archives

# # Install JavaScript dependencies
# ARG NODE_VERSION=20.11.1
# ARG YARN_VERSION=latest
# ENV PATH=/usr/local/node/bin:$PATH
# RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
#     /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
#     npm install -g yarn@$YARN_VERSION && \
#     rm -rf /tmp/node-build-master

# # Install application gems
# COPY Gemfile Gemfile.lock ./
# RUN bundle install && \
#     rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
#     bundle exec bootsnap precompile --gemfile

# # Install node modules
# COPY package.json yarn.lock ./
# RUN yarn install --frozen-lockfile

# # Copy application code
# COPY . .

# # Precompile bootsnap code for faster boot times
# RUN bundle exec bootsnap precompile app/ lib/

# # Precompiling assets for production without requiring secret RAILS_MASTER_KEY
# RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


# RUN rm -rf node_modules


# # Final stage for app image
# FROM base

# # Copy built artifacts: gems, application
# COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
# COPY --from=build /rails /rails

# # Run and own only the runtime files as a non-root user for security
# RUN groupadd --system --gid 1000 rails && \
#     useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
#     chown -R rails:rails db log storage tmp
# USER 1000:1000

# # Entrypoint prepares the database.
# ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# # Start the server by default, this can be overwritten at runtime
# EXPOSE 3000
# CMD ["./bin/rails", "server"]
