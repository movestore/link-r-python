source("src/common/logger.R")
source("src/common/runtime_configuration.R")
source("src/io/app_files.R")
source("src/io/io_handler.R")
source("src/io/rds.R")

library(move2)
library(sf)
library(dplyr)

tryCatch(
    {
      Sys.setenv(tz="UTC")
      
      data <- readInput(sourceFile()) # .rds
      data <- mt_as_event_attribute(data, names(mt_track_data(data)))
      data <- dplyr::mutate(data, coords_x=sf::st_coordinates(data)[,1],
                           coords_y=sf::st_coordinates(data)[,2])
      data.csv <- data.frame(sf::st_drop_geometry(data))
       
      # if (!"individual.taxon.canonical.name" %in% names(data.csv)){
      #   if ("taxon.canonical.name" %in% names(data.csv)) {
      #     names(data.csv)[which(names(data.csv)=="taxon.canonical.name")] <- "individual.taxon.canonical.name"
      #   } else {
      #     data.csv$individual.taxon.canonical.name <- NA
      #   }
      # }
      # # if no local.taxon given, then set NA (Not Available)
      
      write.csv(data.csv,appArtifactPath("link.csv"),row.names=FALSE)
      
      proj <- st_crs(data)[[1]] 
      tz <- attr(mt_time(data),'tzone')
      meta <- data.frame(crs=c(proj), tzone=c(tz))
      # meta <- data.frame(crs=c(proj), tzone=c(tz), timeColName=mt_time_column(data),trackIdColName=mt_track_id_column(data))
      write.csv(meta,appArtifactPath("meta.csv"),row.names=FALSE)
    },
    error = function(e)
    {
        # error handler picks up where error was generated
        print(paste("ERROR: ", e))
        storeToFile(e, errorFile())
        stop(e) # re-throw the exception
    }
)
