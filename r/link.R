# Converts between a move2 object and the CSV pair python reads and writes:
#
#   move2 --writeLink()--> meta.csv + link.csv --(python)--> pickle
#   pickle --(python)--> meta.csv + link.csv --readLink()--> move2
#
# meta.csv carries what a plain CSV cannot: crs, tzone, and which columns hold time and track id.

library("move2")
library("sf")
library("dplyr")
library("vctrs")
library("purrr")
library("rlang")

# meta.csv: one row with what link.csv cannot say itself
linkMeta <- function(data) {
  prj <- st_crs(data)[[1]]
  tz <- attr(mt_time(data),'tzone')
  data.frame(crs=c(prj), tzone=c(tz), timeColName=mt_time_column(data), trackIdColName=mt_track_id_column(data))
}

# link.csv: one row per location, the track attributes repeated on every row, geometry as coordinates
linkTable <- function(data) {
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
  ## UTC instants: a wall-clock time repeats in the autumn DST hour and python could not tell the two apart; meta.csv keeps the tzone
  data.csv[,mt_time_column(data)] <- format(data.csv[,mt_time_column(data)],format="%Y-%m-%d %H:%M:%OS3", tz="UTC") ## if time is 00:00:00 it gets rounded just to the date, and if miliseconds are .000 it gets rounded to seconds when saved as csv. This ensures this does not happen. All timestamps will always have miliseconds.
  data.csv
}

# meta.csv first, then link.csv - the order of v2.2.0
writeLink <- function(data, bufferFile, metaFile) {
  write.csv(linkMeta(data = data), metaFile, row.names=FALSE)
  write.csv(linkTable(data = data), bufferFile, row.names=FALSE)
}

# NULL for an empty buffer or a buffer without rows
readLink <- function(bufferFile, metaFile) {
  # python writes an empty buffer for an empty TrajectoryCollection
  if (file.size(bufferFile) == 0) {
    return(NULL)
  }

  # always includes "coords_x", "coords_y"
  datapy <- read.csv(bufferFile, header=TRUE)
  # always includes crs, tzone, timeColName, trackIdColName
  meta <- read.csv(metaFile, header=TRUE)

  if (dim(datapy)[1]==0) {
    return(NULL)
  }

  datapy[meta$timeColName] <- as.POSIXct(datapy %>% select(meta$timeColName) %>% sapply(as.character) %>% as.vector,format="%Y-%m-%d %H:%M:%S", tz=meta$tzone)
  result <- mt_as_move2(datapy,
                        coords = c("coords_x", "coords_y"),
                        time_column= meta$timeColName,
                        track_id_column= meta$trackIdColName,
                        crs= meta$crs
  )
  result |> dplyr::arrange(mt_track_id(result),mt_time(result))
}
