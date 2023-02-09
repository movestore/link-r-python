source("src/common/logger.R")
source("src/common/runtime_configuration.R")
source("src/io/app_files.R")
source("src/io/io_handler.R")
source("src/io/rds.R")

library(move)

tryCatch(
  {
    Sys.setenv(tz="UTC")
    
    # always includes timestamps, location.long, location.lat, trackId, sensor
    datapy <- read.csv(appArtifactPath("buffer.csv"),header=TRUE)
    # always includes crs and tzone
    meta <- read.csv(appArtifactPath("meta.csv"),header=TRUE) 
    
    if (dim(datapy)[1]==0) result <- NULL else
    {
      o <- order(datapy$trackId,as.POSIXct(datapy$timestamps))
      datapyo <- datapy[o,]
      
      data <- move(
        x=datapyo$location.long,
        y=datapyo$location.lat,
        time=as.POSIXct(datapyo$timestamps),
        proj=CRS(meta$crs),
        sensor=datapyo$sensor,
        animal=datapyo$trackId, #is animal the track ID?
        data=datapyo
      ) 
      
      attr(timestamps(data),'tzone') <- meta$tzone
      result <- moveStack(data,forceTz=meta$tzone)

      storeResult(result = result, outputFile = outputFile)
    }
  },
  error = function(e)
  {
    # error handler picks up where error was generated
    print(paste("ERROR: ", e))
    storeToFile(e, errorFile())
    stop(e) # re-throw the exception
  }
)
