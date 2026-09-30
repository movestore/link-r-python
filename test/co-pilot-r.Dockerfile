########################################################################################################################
# A public stand-in for the private R co-pilot, so CI can build the real App Dockerfile.
# Mirrors co-pilot-v1/co-pilot-r/r/Dockerfile of movestore-groundcontrol: same rocker digest, user, directories and
# renv setup. Left out: the Java part, and the co-pilot's own renv project - the translator brings `moveapps` through
# r/renv.lock. Keep the digest in step with the co-pilot; test/coherence.R can check the R version, not the digest,
# because the co-pilot's registry is private.
########################################################################################################################
# rocker/geospatial:4.6.1
FROM rocker/geospatial@sha256:4cee92a576e26c31546860eb252290f8f259e8236d49600d6bee695dfb96cae5

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
# packages that build a vendored C++ dependency need it, e.g. s2 (Abseil)
    cmake \
    && apt-get clean

ARG username=moveapps
ARG uid=1001
ARG gid=staff
ENV USER=$username
ENV UID=$uid
ENV GID=$gid
ENV HOME=/home/$USER

RUN adduser --disabled-password \
    --gecos "Non-root user" \
    --uid $UID \
    --ingroup $GID \
    --home $HOME \
    $USER
RUN install -d -o moveapps -g staff $HOME/co-pilot-r
RUN install -d -o moveapps -g staff $HOME/.cache/R
USER $USER
WORKDIR $HOME/co-pilot-r

ENV RENV_PATHS_CACHE=$HOME/.cache/R/renv
# The one deviation from the co-pilot, which compiles from https://cloud.r-project.org: P3M binaries of the very
# versions the lock pins, so a cold CI run takes minutes. A version P3M lacks falls back to source (hence cmake).
ENV RENV_CONFIG_REPOS_OVERRIDE=https://p3m.dev/cran/__linux__/noble/latest
ENV RENV_CONFIG_SANDBOX_ENABLED=FALSE

RUN R -e "if (!requireNamespace('renv', quietly = TRUE)) install.packages('renv')"
