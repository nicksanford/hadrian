# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian instead of
# Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20210902-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.12.0-erlang-24.0.1-debian-bullseye-20210902-slim
#
ARG ELIXIR_VERSION=1.13.4
ARG OTP_VERSION=24.0.1
ARG DEBIAN_VERSION=bullseye-20210902-slim

ARG IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG MIX_ENV="dev"

FROM ${IMAGE} as image 

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git inotify-tools \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV

# # install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

# # copy compile-time config files before we compile dependencies
# # to ensure any relevant config change will trigger the dependencies
# # to be re-compiled.
RUN mix deps.compile

# # Compile the release
COPY lib lib
COPY priv priv
COPY test test

RUN mix compile
COPY config config

CMD ["iex", "-S", "mix"]
