source("src/common/logger.R")
source("src/common/runtime_configuration.R")
source("src/io/app_files.R")
source("src/io/io_handler.R")
source("src/io/rds.R")

library("move2")
library("sf")
library("dplyr")
library("vctrs")
library("purrr")
library("rlang")

tryCatch(
    {
      Sys.setenv(tz="UTC")
      
      data <- readInput(sourceFile()) # .rds
      
      ## get meta.csv
      prj <- st_crs(data)[[1]] 
      tz <- attr(mt_time(data),'tzone')
      meta <- data.frame(crs=c(prj), tzone=c(tz), timeColName=mt_time_column(data), trackIdColName=mt_track_id_column(data))
      write.csv(meta,Sys.getenv(x = "LINK_R_PYTHON_META"),row.names=FALSE)
      
      ## get link.csv
      ## checking if there are columns in the track data that are a list. If yes, check if the content is the same, if yes remove list. If list columns are left over because content is different transform these into a character string (could be done as well as json, but think that average user will be more comfortable with text?. Easy to change in the future. See Issue #78 on move2)
      if(any(sapply(mt_track_data(data), is_bare_list))){
        ## reduce all columns were entry is the same to one (so no list anymore)
        data <- data |> mutate_track_data(across(
          where( ~is_bare_list(.x) && all(purrr::map_lgl(.x, function(y) 1==length(unique(y)) ))), 
          ~do.call(vctrs::vec_c,purrr::map(.x, head,1))))
        if(any(sapply(mt_track_data(data), is_bare_list))){
          ## transform those that are still a list into a character string
          data <- data |> mutate_track_data(across(
            where( ~is_bare_list(.x) && any(purrr::map_lgl(.x, function(y) 1!=length(unique(y)) ))), 
            ~unlist(purrr::map(.x, paste, collapse=","))))
        }
      }
      data <- mt_as_event_attribute(data, names(mt_track_data(data)))
      data <- dplyr::mutate(data, coords_x=sf::st_coordinates(data)[,1],
                            coords_y=sf::st_coordinates(data)[,2])
      data <- sf::st_drop_geometry(data) ## removes the sf geometry column from the table
      sfc_cols <- names(data)[unlist(lapply(data, inherits, 'sfc'))] ## get the col names that are spacial
      
      for(x in sfc_cols){ ## converting the "point" columns into characters, ie into WKT (Well-known text)
        data[[x]] <- st_as_text(data[[x]])
      } ## st_as_sfc() can be used to convert these columns back to spacial
      
      data.csv <- data.frame(data)
      data.csv[,mt_time_column(data)] <- format(data.csv[,mt_time_column(data)],format="%Y-%m-%d %H:%M:%OS3") ## if time is 00:00:00 it gets rounded just to the date, and if miliseconds are .000 it gets rounded to seconds when saved as csv. This ensures this does not happen. All timestamps will always have miliseconds.

      write.csv(data.csv,Sys.getenv(x = "LINK_R_PYTHON_BUFFER"),row.names=FALSE)
  
    },
    error = function(e)
    {
        # error handler picks up where error was generated
        print(paste("ERROR: ", e))
        storeToFile(e, errorFile())
        stop(e) # re-throw the exception
    }
)
