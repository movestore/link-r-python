library("moveapps")
moveapps::logger.init()
source("link.R")

tryCatch(
  {
    Sys.setenv(tz="UTC")

    # NULL for an empty buffer: storeResult then writes the empty file the next App reads as NULL input
    moveapps::storeResult(result = readLink(bufferFile = Sys.getenv(x = "LINK_R_PYTHON_BUFFER"), metaFile = Sys.getenv(x = "LINK_R_PYTHON_META")), outputFile = moveapps::outputFile())
  },
  error = function(e)
  {
    # error handler picks up where error was generated
    print(paste("ERROR: ", e))
    moveapps::storeToFile(e, moveapps::errorFile())
    stop(e) # re-throw the exception
  }
)
