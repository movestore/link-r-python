# Runs the Python unit tests in the environment the App uses.
# The base tag is the python co-pilot's own base, whose /opt/conda the App copies; test/coherence.R
# holds CI to it. Pinned on purpose: in the sibling repo `cargo-agent-python` a floating `:latest`
# silently moved to a base without `adduser` and broke the build.
# linux/amd64: python/conda-linux-64.lock holds linux-64 packages only, so an arm64 host emulates.
FROM --platform=linux/amd64 condaforge/miniforge3:26.7.2-0
LABEL org.opencontainers.image.authors="us@couchbits.com"
LABEL org.opencontainers.image.vendor="couchbits GmbH"

ENV PROJECT_DIR=/opt/link-r-python
ENV ENV_PREFIX=${PROJECT_DIR}/conda

WORKDIR $PROJECT_DIR
# the environment first, so its layer caches independently of the sources.
# lock (default): what the App installs. fresh: environment.yml resolved today - what the next lock would
# be, for the weekly run.
ARG ENVIRONMENT=lock
COPY python/environment.yml python/conda-linux-64.lock ./python/
RUN case "$ENVIRONMENT" in \
      lock) conda create --yes --prefix ${ENV_PREFIX} --file python/conda-linux-64.lock ;; \
      fresh) conda env create --prefix ${ENV_PREFIX} --file python/environment.yml ;; \
      *) echo "ENVIRONMENT must be lock or fresh" >&2; exit 1 ;; \
    esac && \
    conda clean --all --yes
# what got installed, for the weekly comparison with the lock
RUN conda list --prefix ${ENV_PREFIX} --explicit --md5 | grep '^https' > resolved.txt

COPY python/ ./python/
# the golden CSV pairs the contract test reads, shared with the R tests
COPY test/contract/ ./test/contract/

# `--no-capture-output` or conda swallows the result, including a failure.
# The test modules are named explicitly: they use relative imports and there is no
# `__init__.py`, so `unittest discover` does not find them reliably.
RUN conda run --no-capture-output --prefix ${ENV_PREFIX} python -m unittest \
    python.tests.test_transform_to_pickle python.tests.test_transform_to_csv python.tests.test_contract
