library("moveapps")
moveapps::logger.init()
source("link.R")

tryCatch(
  {
    Sys.setenv(tz="UTC")

    result <- readLink(bufferFile = Sys.getenv(x = "LINK_R_PYTHON_BUFFER"), metaFile = Sys.getenv(x = "LINK_R_PYTHON_META"))
    # v2.2.0 stores no output at all for a buffer without rows
    if (!is.null(result)) moveapps::storeResult(result = result, outputFile = moveapps::outputFile())
  },
  error = function(e)
  {
    # error handler picks up where error was generated
    print(paste("ERROR: ", e))
    moveapps::storeToFile(e, moveapps::errorFile())
    stop(e) # re-throw the exception
  }
)
