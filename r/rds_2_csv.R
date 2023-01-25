source("src/common/logger.R")
source("src/common/runtime_configuration.R")
source("src/io/app_files.R")
source("src/io/io_handler.R")
source("src/io/rds.R")

library(move)

tryCatch(
    {
        Sys.setenv(tz="UTC")
        data <- readInput(sourceFile()) # .rds

        data.csv <- as.data.frame(data)
        names(data.csv) <- make.names(names(data.csv),allow_=FALSE)
        # use for geopandas: trackId, timestamps, location.lat and location.long (plus all the attributes as a table)
        write.csv(data.csv, appArtifactPath("buffer.csv"),row.names=FALSE) 

        projection <- raster::projection(data) # for move2 this will be st_crs()
        tz <- attr(timestamps(data),'tzone')
        write.csv(data.frame("crs"=c(projection), "tzone"=c(tz)),appArtifactPath("meta.csv"),row.names=FALSE) #or any other format
    },
    error = function(e)
    {
        # error handler picks up where error was generated
        print(paste("ERROR: ", e))
        storeToFile(e, errorFile())
        stop(e) # re-throw the exception
    })
