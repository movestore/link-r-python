# Checks a round trip against its pins (see describe.R), then the invariants no pin may relax: the
# track of every row, the coordinates, the crs, and every input column present on the way back.
#   Rscript compare.R <cases> <expected.csv> <classes.csv>
here <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)))
source(file.path(here, "describe.R"))

args <- commandArgs(trailingOnly = TRUE)
described <- describeAll(cases = args[1])
failures <- character()

# the pins, line by line
actualExpected <- tempfile(fileext = ".csv")
actualClasses <- tempfile(fileext = ".csv")
writeDescription(described = described, expectedFile = actualExpected, classesFile = actualClasses)
for (files in list(c(args[2], actualExpected), c(args[3], actualClasses))) {
  pinned <- readLines(files[1])
  measured <- readLines(files[2])
  # sprintf, not paste0: paste0 turns an empty difference into one line
  failures <- c(failures,
                sprintf("%s, pinned but not measured: %s", basename(files[1]), setdiff(pinned, measured)),
                sprintf("%s, measured but not pinned: %s", basename(files[1]), setdiff(measured, pinned)))
}

# the invariants
for (case in described) {
  if (is.null(case$aligned)) next
  name <- case$summary$case
  input <- case$aligned$input
  output <- case$aligned$output

  if (nrow(input) != nrow(output)) {
    failures <- c(failures, sprintf("%s: %d input rows in the kept tracks, %d rows back", name, nrow(input), nrow(output)))
    next
  }
  if (!identical(as.character(mt_track_id(input)), as.character(mt_track_id(output)))) {
    failures <- c(failures, sprintf("%s: the track of a row changed", name))
  }
  coordinatesIn <- st_coordinates(input)
  coordinatesOut <- st_coordinates(output)
  if (any(abs(coordinatesIn - coordinatesOut) > 1e-12 * pmax(1, abs(coordinatesIn)))) {
    failures <- c(failures, sprintf("%s: coordinates changed", name))
  }
  if (st_crs(case$input) != st_crs(case$output)) {
    failures <- c(failures, sprintf("%s: crs changed", name))
  }
  lost <- setdiff(case$namesIn, case$namesOut)
  if (length(lost) > 0) {
    failures <- c(failures, sprintf("%s: columns lost: %s", name, paste(lost, collapse = ", ")))
  }
}

if (length(failures) > 0) {
  cat(failures, sep = "\n")
  quit(status = 1)
}
cat(sprintf("round trip: %d cases as pinned\n", length(described)))
