# Cuts the contract cases out of the sample inputs: a few rows each, by row number of the full input.
#   Rscript cut.R <raw dir> <contract dir>
suppressMessages(library("move2"))

cases <- list(
  "latlon-three-tracks" = list(file = "input4_move2loc_LatLon.rds", rows = c(1:4, 3011:3014, 4506:4509)),
  "mollweide-midnight" = list(file = "input1_move2loc_Mollweide.rds", rows = 2728:2731),
  "subsecond" = list(file = "input2_move2loc_LatLon.rds", rows = 3443:3446),
  "argos-sfc" = list(file = "input3_move2loc_LatLon.rds", rows = c(1, 2, 25, 26, 63, 64, 365, 366, 938, 939)),
  "list-columns" = list(file = "input_move2loc_List.rds", rows = 1:5),
  "berlin" = list(file = "input1_move2loc_LatLon.rds", rows = 1:4, tzone = "Europe/Berlin")
)

args <- commandArgs(trailingOnly = TRUE)
for (name in names(cases)) {
  spec <- cases[[name]]
  data <- readRDS(file.path(args[1], spec$file))[spec$rows, ]
  if (!is.null(spec$tzone)) {
    attr(data[[mt_time_column(data)]], "tzone") <- spec$tzone
  }
  dir.create(file.path(args[2], name), recursive = TRUE, showWarnings = FALSE)
  saveRDS(data, file.path(args[2], name, "input.rds"))
}
