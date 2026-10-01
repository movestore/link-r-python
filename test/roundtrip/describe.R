# Describes what the round trip R -> python -> R did to every case directory in <cases>:
#   <case>/input.rds       what went in (absent for a python-born case)
#   <case>/r2python.exit   exit code of the R -> python App; <case>/r2python.log its log
#   <case>/python2r.exit   exit code of the python -> R App
#   <case>/output.rds      what came back (absent if an App failed, empty for the NULL result)
#
# Sourced by compare.R. Run as a script it pins the description:
#   Rscript describe.R <cases> <expected.csv> <classes.csv>

suppressMessages({
  library("move2")
  library("sf")
})

readExit <- function(file) {
  if (file.exists(file)) as.integer(readLines(file, n = 1)) else NA_integer_
}

classOf <- function(x) paste(class(x), collapse = "/")

# the input rows of the tracks the output kept, and the output, both ordered by track id and time;
# radix ordering is locale-free, so two images with different locales order alike
alignRows <- function(input, output) {
  input <- input[as.character(mt_track_id(input)) %in% as.character(mt_track_id(output)), ]
  list(
    input = input[order(as.character(mt_track_id(input)), as.numeric(mt_time(input)), method = "radix"), ],
    output = output[order(as.character(mt_track_id(output)), as.numeric(mt_time(output)), method = "radix"), ]
  )
}

describeCase <- function(dir) {
  case <- basename(dir)
  log <- file.path(dir, "r2python.log")
  summary <- data.frame(
    case = case,
    r2python_exit = readExit(file.path(dir, "r2python.exit")),
    python2r_exit = readExit(file.path(dir, "python2r.exit")),
    rows_out = NA_integer_,
    tracks_out = NA_integer_,
    max_time_deviation_s = NA_character_,
    time_column_out = NA_character_,
    tzone_out = NA_character_,
    dropped_tracks_warned = if (file.exists(log)) sum(grepl("^\\[WARN\\] track ", readLines(log, warn = FALSE))) else NA_integer_
  )
  described <- list(summary = summary, classes = NULL, aligned = NULL)

  outputFile <- file.path(dir, "output.rds")
  if (!file.exists(outputFile)) {
    return(described)
  }
  if (file.size(outputFile) == 0) {
    described$summary$rows_out <- 0L
    return(described)
  }

  output <- readRDS(outputFile)
  described$summary$rows_out <- nrow(output)
  described$summary$tracks_out <- mt_n_tracks(output)
  described$summary$time_column_out <- mt_time_column(output)
  described$summary$tzone_out <- attr(mt_time(output), "tzone")

  inputFile <- file.path(dir, "input.rds")
  if (!file.exists(inputFile)) {
    return(described)
  }
  input <- readRDS(inputFile)
  aligned <- alignRows(input = input, output = output)
  if (nrow(aligned$input) == nrow(aligned$output) && nrow(aligned$output) > 0) {
    deviation <- abs(as.numeric(mt_time(aligned$input)) - as.numeric(mt_time(aligned$output)))
    described$summary$max_time_deviation_s <- sprintf("%.3f", max(deviation))
  }

  # the input as it travels: track attributes become event attributes on the way out
  events <- mt_as_event_attribute(input, names(mt_track_data(input)))
  namesIn <- setdiff(names(events), attr(events, "sf_column"))
  namesOut <- setdiff(names(output), attr(output, "sf_column"))
  columns <- union(namesIn, namesOut)
  described$classes <- data.frame(
    case = case,
    column = columns,
    class_in = vapply(columns, function(column) if (column %in% namesIn) classOf(events[[column]]) else NA_character_, character(1)),
    class_out = vapply(columns, function(column) if (column %in% namesOut) classOf(output[[column]]) else NA_character_, character(1)),
    row.names = NULL
  )

  described$aligned <- aligned
  described$input <- input
  described$output <- output
  described$namesIn <- namesIn
  described$namesOut <- namesOut
  described
}

describeAll <- function(cases) {
  lapply(sort(list.dirs(cases, recursive = FALSE), method = "radix"), describeCase)
}

# one CSV line per case, and one per case and column
writeDescription <- function(described, expectedFile, classesFile) {
  write.csv(do.call(rbind, lapply(described, `[[`, "summary")), expectedFile, row.names = FALSE, na = "")
  write.csv(do.call(rbind, lapply(described, `[[`, "classes")), classesFile, row.names = FALSE, na = "")
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  writeDescription(described = describeAll(cases = args[1]), expectedFile = args[2], classesFile = args[3])
}
