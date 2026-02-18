# syntax=docker/dockerfile:1

#############################################
# 1) Imagen base: Ruby + dependencias runtime
#############################################
ARG RUBY_VERSION=3.3.0
FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base

WORKDIR /rails

# Instala dependencias de runtime
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl libjemalloc2 postgresql-client libpq-dev libvips redis-tools && \
    rm -rf /var/lib/apt/lists/*

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle"

#############################################
# 2) Stage de build: compilamos gems + assets
#############################################
FROM base AS build

# Añade compiladores y SQLite solo para build
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential git pkg-config \
      sqlite3 libsqlite3-dev && \
    rm -rf /var/lib/apt/lists/*

# Instalamos gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copiamos el código
COPY . .

# Stub temporal a SQLite SOLO este stage, para no necesitar Postgres al precompile
RUN rm -f config/database.yml && \
    mkdir -p db && \
    cat > config/database.yml <<-YML
production:
  adapter: sqlite3
  database: db/production.sqlite3
  pool: 5
YML

# Precompilamos assets sin levantar ActiveRecord en Postgres
ENV SECRET_KEY_BASE=dummy
# Compilamos Tailwind CSS antes de precompilar assets
RUN bundle exec rails tailwindcss:build
RUN bundle exec rails assets:precompile

#############################################
# 3) Stage final: runtime con Postgres real
#############################################
FROM base AS final

WORKDIR /rails

# Copiamos las gems instaladas
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"

# Copiamos SOLO los assets generados
COPY --from=build /rails/public/assets ./public/assets

# Copiamos el código y la configuración real, incluyendo tu database.yml de Postgres
COPY . .

# Creamos un usuario no-root para runtime
RUN groupadd --system --gid 1000 rails && \
    useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash rails && \
    chown -R rails:rails db log storage tmp public/assets

USER rails

# Entrypoint y comando por defecto
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
