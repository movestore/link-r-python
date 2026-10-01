# Derives the non-UTC round-trip cases from input1. Movebank data are UTC; these are the edge cases.
#   input1_move2loc_LatLon_berlin.rds - all of input1, displayed in Europe/Berlin
#   dst_ambiguous.rds                 - two fixes at 00:30 and 01:30 UTC on 2021-10-31, both 02:30 local
#   Rscript synthetic.R <input1.rds> <out dir>
suppressMessages(library("move2"))

args <- commandArgs(trailingOnly = TRUE)
input1 <- readRDS(args[1])

berlin <- input1
attr(berlin[[mt_time_column(berlin)]], "tzone") <- "Europe/Berlin"
saveRDS(berlin, file.path(args[2], "input1_move2loc_LatLon_berlin.rds"))

ambiguous <- input1[1:2, ]
ambiguous[[mt_time_column(ambiguous)]] <- as.POSIXct(c("2021-10-31 00:30:00", "2021-10-31 01:30:00"), tz = "UTC")
attr(ambiguous[[mt_time_column(ambiguous)]], "tzone") <- "Europe/Berlin"
saveRDS(ambiguous, file.path(args[2], "dst_ambiguous.rds"))
