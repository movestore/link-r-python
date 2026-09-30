# The versions pinned in separate files must agree - nothing else compares them.
#   Rscript coherence.R <repository root>        (inside the test image: R is the stand-in's)
root <- commandArgs(trailingOnly = TRUE)[1]

field <- function(text, pattern) {
  match <- regmatches(text, regexec(pattern, text))[[1]]
  if (length(match) == 2) match[2] else NA_character_
}

base <- grep("^ARG BASE=", readLines(file.path(root, "Dockerfile")), value = TRUE)
lock <- jsonlite::fromJSON(file.path(root, "r", "renv.lock"))
bake <- paste(readLines(file.path(root, "test", "docker-bake.hcl")), collapse = "\n")
testDockerfile <- paste(readLines(file.path(root, "test", "Dockerfile")), collapse = "\n")

check <- function(label, left, right) {
  ok <- !is.na(left) && !is.na(right) && identical(left, right)
  cat(sprintf("%s %s: %s / %s\n", if (ok) "ok  " else "FAIL", label, left, right))
  ok
}

results <- c(
  check("R of this image / R in r/renv.lock", as.character(getRversion()), lock$R$Version),
  check("R in r/renv.lock / geospatial-X of BASE", lock$R$Version, field(base, "_geospatial-([0-9.]+)_")),
  check("moveapps in r/renv.lock / sdk-vX of BASE", lock$Packages$moveapps$Version, field(base, "_sdk-v([0-9.]+)_")),
  check("Miniforge CI passes as CONDA / Miniforge of test/Dockerfile",
        field(bake, 'default = "condaforge/miniforge3:([0-9A-Za-z._-]+)"'),
        field(testDockerfile, "FROM condaforge/miniforge3:([0-9A-Za-z._-]+)"))
)
if (!all(results)) quit(status = 1)
