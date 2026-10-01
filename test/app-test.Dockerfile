# Runs the coherence check, the R unit tests and the round trip inside the real App images.
FROM app-r2python

# the python -> R entry point; everything else in the two images is identical
COPY --from=app-python2r --chown=$UID:$GID /home/moveapps/co-pilot-r/start-process.sh /home/moveapps/co-pilot-r/start-process-python2r.sh

# testthat is a test dependency only: installed here, never part of the App's lock
WORKDIR /home/moveapps/co-pilot-r/r
RUN R -q -e 'renv::install("testthat@3.3.2")'

WORKDIR /home/moveapps/co-pilot-r
COPY --chown=$UID:$GID Dockerfile ./Dockerfile
COPY --chown=$UID:$GID python/environment.yml python/conda-linux-64.lock ./python/
COPY --chown=$UID:$GID test/ ./test/
COPY --chown=$UID:$GID r/tests/ ./r/tests/
COPY --chown=$UID:$GID r/data/raw/ ./r/data/raw/

RUN cd r && Rscript ../test/coherence.R ..
RUN cd r && Rscript -e 'testthat::test_dir("tests/testthat")'
RUN test/roundtrip/run.sh
