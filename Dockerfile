# Builds either translator App - `DIRECTION` below says which. The platform passes no build
# arguments: BASE and CONDA fall back to their defaults, and DIRECTION must be set in the copy of this
# file that goes onto the App version (see README).
ARG BASE=registry.gitlab.com/couchbits/movestore/movestore-groundcontrol/co-pilot-r:v4.0.0_sdk-v1.0.3_geospatial-4.6.1_4674
# The python co-pilot, for its conda: FROM condaforge/miniforge3:26.7.2-0, /opt/conda untouched.
# Taken from the platform's registry, not Docker Hub: no App version has ever pulled from elsewhere,
# and the platform's builder holds no Docker Hub credentials.
ARG CONDA=registry.gitlab.com/couchbits/movestore/movestore-groundcontrol/co-pilot-v1-python:v3.1.0

FROM ${CONDA} AS conda

FROM ${BASE}
COPY --from=conda /opt/conda /opt/conda
ENV PATH=/opt/conda/bin:$PATH
# conda caches in ~/.cache/conda, but the co-pilot created ~/.cache as root (for ~/.cache/R)
USER root
RUN install -d -o $UID -g $GID $HOME/.cache/conda
USER $USER

# the app
ENV PROJECT_DIR=$HOME/co-pilot-r
WORKDIR $PROJECT_DIR

# the python part: the explicit lock python/lock.sh resolves from python/environment.yml, so the App gets
# exactly what CI tested
WORKDIR $PROJECT_DIR/python
COPY --chown=$UID:$GID python/conda-linux-64.lock /tmp/
# keep in mind that anaconda aka channel `conda` is blocked in production env
# https://gitlab.mpcdf.mpg.de/mpcdf-hpc-cloud/mvpr-moveapps/-/issues/29
# miniforge uses channel `conda-forge` as default - so nothing to do here
ENV ENV_PREFIX=$PROJECT_DIR/python-env
RUN conda create --yes --prefix $ENV_PREFIX --file /tmp/conda-linux-64.lock && \
    conda clean --all --yes

# the r part: the translator's own renv project in r/
WORKDIR $PROJECT_DIR/r
# cleanup: the co-pilot's own renv project and entry point; the translator brings both
RUN rm -rf ../renv ../renv.lock ../.Rprofile ../RFunction.R ../app.R
# renv: restore the current snapshot
COPY --chown=$UID:$GID r/renv.lock r/.Rprofile ./
COPY --chown=$UID:$GID r/renv/activate.R r/renv/settings.dcf ./renv/
RUN R -e 'renv::restore()'
# be prepared for the hangar inspection
RUN cp renv.lock ../

# the project: both directions, so both Apps share every layer up to here
WORKDIR $PROJECT_DIR
COPY --chown=$UID:$GID python/csv_2_pickle.py python/transform_to_pickle.py python/pickle_2_csv.py python/transform_to_csv.py ./python/
COPY --chown=$UID:$GID r/link.R r/rds_2_csv.R r/csv_2_rds.R ./r/
COPY --chown=$UID:$GID r2python.sh python2r.sh ./

# The one line in which the two Apps differ: r2python (move2_loc to MovingPandas) or python2r
# (MovingPandas to move2_loc). No default on purpose - a forgotten edit must fail the build, not
# silently build the other App. Declared last: a changed ARG invalidates every RUN after it.
# The start script is picked here, not by `COPY ${DIRECTION}.sh`: BuildKit resolves a COPY source
# before this check has run, and fails on "/.sh: not found" instead of the message.
ARG DIRECTION
RUN case "$DIRECTION" in \
      r2python|python2r) mv "$DIRECTION.sh" start-process.sh && rm -f r2python.sh python2r.sh ;; \
      *) echo "DIRECTION must be r2python or python2r" >&2; exit 1 ;; \
    esac
