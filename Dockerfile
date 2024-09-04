FROM registry.gitlab.com/couchbits/movestore/movestore-groundcontrol/co-pilot-v3-r:sdk-v3.2.0_geospatial-4.3.2_3649

# install micromamba
# kudos: https://github.com/mamba-org/micromamba-releases/blob/main/install.sh
# alternative: https://mamba.readthedocs.io/en/latest/installation/micromamba-installation.html#manual-installation
ENV BIN_FOLDER=$HOME/.local/bin
ENV ROOT_PREFIX=$HOME/conda
ENV ARCH="64"
ENV PLATFORM="linux"
ENV RELEASE_URL="https://github.com/mamba-org/micromamba-releases/releases/latest/download/micromamba-${PLATFORM}-${ARCH}"
# Downloading artifact
RUN mkdir -p "${BIN_FOLDER}"
RUN wget ${WGET_OPTS:-} -qO "${BIN_FOLDER}/micromamba" "${RELEASE_URL}" && \
    chmod +x "${BIN_FOLDER}/micromamba" && \
    ${BIN_FOLDER}/micromamba shell init -s bash --root-prefix ${ROOT_PREFIX} && \
    ${BIN_FOLDER}/micromamba config append channels conda-forge

# the app
ENV PROJECT_DIR $HOME/co-pilot-r
WORKDIR $PROJECT_DIR

# the python part
WORKDIR $PROJECT_DIR/python
COPY --chown=$UID:$GID python/environment.yml .
# build the conda environment
ENV ENV_PREFIX $PROJECT_DIR/python-env
RUN ${BIN_FOLDER}/micromamba create --prefix ${ENV_PREFIX} --file ./environment.yml && \
    ${BIN_FOLDER}/micromamba clean --all --yes

# the r part
WORKDIR $PROJECT_DIR/r
# move the co-pilot-r sdk into this sub-directory
USER root:root
RUN mv ../src .
# cleanup: remove unusuded files form co-pilot-r
RUN rm -rf ../renv ../renv.lock ../.Rprofile ../RFunction.R src/io/shiny_bookmark_handler.R
# patch the co-pilot-r file `src/io/rds.R` in order to not dependend on `move1`
COPY r/src/io/rds.R src/io/rds.R
USER $USER
# renv: restore the current snapshot
COPY --chown=$UID:$GID r/renv.lock r/.Rprofile ./
COPY --chown=$UID:$GID r/renv/activate.R r/renv/settings.dcf ./renv/
RUN R -e 'renv::restore()'
# be prepared for the hangar inspection
RUN cp renv.lock ../

# the project
WORKDIR $PROJECT_DIR
# r -> python
COPY --chown=$UID:$GID python/csv_2_pickle.py python/transform_to_pickle.py ./python/
COPY --chown=$UID:$GID r/rds_2_csv.R ./r/
# python -> r
COPY --chown=$UID:$GID python/pickle_2_csv.py python/transform_to_csv.py ./python/
COPY --chown=$UID:$GID r/csv_2_rds.R ./r/

# r -> python
#COPY --chown=$UID:$GID r2python.sh start-process.sh
# python -> r
# COPY --chown=$UID:$GID python2r.sh start-process.sh
COPY --chown=$UID:$GID r2python.sh python2r.sh ./
