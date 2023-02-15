FROM registry.gitlab.com/couchbits/movestore/movestore-groundcontrol/co-pilot-v1-r:geospatial-4.2.2-3188

# install miniconda
ENV MINICONDA_VERSION latest
ENV CONDA_DIR $HOME/miniconda3
RUN wget --quiet -O ~/Miniforge3.sh "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" && \
    chmod +x ~/Miniforge3.sh && \
    bash ~/Miniforge3.sh -b -p $CONDA_DIR && \
    rm ~/Miniforge3.sh
# make non-activate conda commands available
ENV PATH=$CONDA_DIR/bin:$PATH
# make conda activate command available from /bin/bash --login shells
RUN echo ". $CONDA_DIR/etc/profile.d/conda.sh" >> ~/.profile
# make conda activate command available from /bin/bash --interative shells
RUN conda init bash

USER $USER

# the app
ENV PROJECT_DIR $HOME/co-pilot-r
WORKDIR $PROJECT_DIR

# the python part
WORKDIR $PROJECT_DIR/python
COPY --chown=$UID:$GID python/environment.yml /tmp/
# build the conda environment
ENV ENV_PREFIX $PROJECT_DIR/python-env
RUN conda update --name base --channel defaults conda && \
    conda env create --prefix $ENV_PREFIX --file /tmp/environment.yml --force && \
    conda clean --all --yes

# the r part
WORKDIR $PROJECT_DIR/r
# move the co-pilot-r sdk into this sub-directory
RUN mv ../src .
# renv
COPY --chown=$UID:$GID r/renv.lock r/.Rprofile ./
COPY --chown=$UID:$GID r/renv/activate.R ./renv/
ENV RENV_VERSION 0.16.0
RUN R -e "install.packages('remotes', repos = c(CRAN = 'https://cloud.r-project.org'))"
RUN R -e "remotes::install_github('rstudio/renv@${RENV_VERSION}')"
RUN R -e 'renv::restore()'
# setup hangar inspection
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
#COPY --chown=$UID:$GID python2r.sh start-process.sh
