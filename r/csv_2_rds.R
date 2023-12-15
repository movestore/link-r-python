source("src/common/logger.R")
source("src/common/runtime_configuration.R")
source("src/io/app_files.R")
source("src/io/io_handler.R")
source("src/io/rds.R")

library(move2)
library(dplyr)

tryCatch(
  {
    Sys.setenv(tz="UTC")
    
    # always includes timestamps, location.long, location.lat, trackId, sensor
    datapy <- read.csv(appArtifactPath("link.csv"),header=TRUE)
    # always includes crs and tzone
    meta <- read.csv(appArtifactPath("meta.csv"),header=TRUE) 
    
    if (dim(datapy)[1]==0) result <- NULL else
    {
      datapy$timestamp <- as.POSIXct(datapy$timestamp,format="%Y-%m-%d %H:%M:%S", tz=meta$tzone)      
      result <- mt_as_move2(datapy,
                          coords = c("coords_x", "coords_y"),
                          time_column="timestamp", # meta$trackIdColName,
                          track_id_column= "individual_name_deployment_id", # meta$trackIdColName,
                          # track_attributes=c(),
                          crs= meta$crs
      )
      ## add remove empty locs??
      result <- result |> dplyr::arrange(mt_track_id(result),mt_time(result))
      
      storeResult(result = result, outputFile = outputFile())
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
