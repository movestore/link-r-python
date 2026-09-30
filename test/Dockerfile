# Runs the Python unit tests in the environment the App uses.
# The base tag is the python co-pilot's own base, whose /opt/conda the App copies; test/coherence.R
# holds CI to it. Pinned on purpose: in the sibling repo `cargo-agent-python` a floating `:latest`
# silently moved to a base without `adduser` and broke the build.
FROM condaforge/miniforge3:26.7.2-0
LABEL org.opencontainers.image.authors="us@couchbits.com"
LABEL org.opencontainers.image.vendor="couchbits GmbH"

ENV PROJECT_DIR=/opt/link-r-python
ENV ENV_PREFIX=${PROJECT_DIR}/conda

WORKDIR $PROJECT_DIR
# the environment first, so its layer caches independently of the sources
COPY python/environment.yml ./python/
RUN conda env create --prefix ${ENV_PREFIX} --file python/environment.yml && \
    conda clean --all --yes

COPY python/ ./python/
# the golden CSV pairs the contract test reads, shared with the R tests
COPY test/contract/ ./test/contract/

# `--no-capture-output` or conda swallows the result, including a failure.
# The test modules are named explicitly: they use relative imports and there is no
# `__init__.py`, so `unittest discover` does not find them reliably.
RUN conda run --no-capture-output --prefix ${ENV_PREFIX} python -m unittest \
    python.tests.test_transform_to_pickle python.tests.test_transform_to_csv python.tests.test_contract
