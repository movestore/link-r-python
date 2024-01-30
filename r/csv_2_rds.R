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
    
    # always includes "coords_x", "coords_y"
    datapy <- read.csv(appArtifactPath("link.csv"),header=TRUE)
    # always includes crs, tzone, timeColName, trackIdColName
    meta <- read.csv(appArtifactPath("meta.csv"),header=TRUE) 
    
    if (dim(datapy)[1]==0) result <- NULL else
    {
      datapy[meta$timeColName] <- as.POSIXct(datapy %>% select(meta$timeColName) %>% sapply(as.character) %>% as.vector,format="%Y-%m-%d %H:%M:%S", tz=meta$tzone)      
      result <- mt_as_move2(datapy,
                          coords = c("coords_x", "coords_y"),
                          time_column= meta$timeColName,
                          track_id_column= meta$trackIdColName,
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
