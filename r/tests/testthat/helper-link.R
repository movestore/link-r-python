# the code under test, and the contract cases shared with the python tests
source(file.path("..", "..", "link.R"))

contractDir <- file.path("..", "..", "..", "test", "contract")
contractCases <- basename(list.dirs(contractDir, recursive = FALSE))

readCase <- function(case) readRDS(file.path(contractDir, case, "input.rds"))

writeTempLines <- function(lines) {
  file <- tempfile(fileext = ".csv")
  writeLines(lines, file)
  file
}

metaFileFor <- function(tzone = "UTC") {
  writeTempLines(c(
    "crs,tzone,timeColName,trackIdColName",
    sprintf("EPSG:4326,%s,timestamp_utc,track", tzone)
  ))
}
