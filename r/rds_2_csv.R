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
      
      # Remove apparently duplicated columns, but which are
      # often not true duplicates. Just to avoid mistakes 
      # that could mess all up and no one would understand why
      data.csv$timestamps <- timestamps(data)
      if("timestamp" %in% names(data.csv)){data.csv$timestamp <- NULL}
      data.csv$location.long <- coordinates(data)[,1]
      data.csv$location.lat <- coordinates(data)[,2]
      if("coords.x1" %in% names(data.csv)){data.csv[,c("coords.x1","coords.x2")] <- NULL}
      data.csv$sensor <- sensor(data)
      if("sensor.type" %in% names(data.csv)){data.csv$sensor.type <- NULL}
      
      if (!"individual.local.identifier" %in% names(data.csv)){
        if ("local.identifier" %in% names(data.csv)) {
          names(data.csv)[which(names(data.csv)=="local.identifier")] <- "individual.local.identifier"
        } else {
          # keep the trackId column, for consistency
          data.csv$individual.local.identifier <- data.csv$trackId}
      } 
      # if no local.identifier given, then use trackId (which is always there)
      
      if (!"individual.taxon.canonical.name" %in% names(data.csv)){
        if ("taxon.canonical.name" %in% names(data.csv)) {
          names(data.csv)[which(names(data.csv)=="taxon.canonical.name")] <- "individual.taxon.canonical.name"
        } else {
          data.csv$individual.taxon.canonical.name <- NA
        }
      }
      # if no local.taxon given, then set NA (Not Available)
      
      write.csv(data.csv,appArtifactPath("buffer.csv"),row.names=FALSE)
      
      projection <- raster::projection(data) # for move2 this will be st_crs()
      tz <- attr(timestamps(data),'tzone')
      write.csv(data.frame("crs"=c(projection), "tzone"=c(tz)),appArtifactPath("meta.csv"),row.names=FALSE)
    },
    error = function(e)
    {
        # error handler picks up where error was generated
        print(paste("ERROR: ", e))
        storeToFile(e, errorFile())
        stop(e) # re-throw the exception
    }
)
