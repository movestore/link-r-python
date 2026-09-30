source("src/common/logger.R")
source("src/common/runtime_configuration.R")
source("src/io/app_files.R")
source("src/io/io_handler.R")
source("src/io/rds.R")
source("link.R")

tryCatch(
  {
    Sys.setenv(tz="UTC")

    result <- readLink(bufferFile = Sys.getenv(x = "LINK_R_PYTHON_BUFFER"), metaFile = Sys.getenv(x = "LINK_R_PYTHON_META"))
    # v2.2.0 stores no output at all for a buffer without rows
    if (!is.null(result)) storeResult(result = result, outputFile = outputFile())
  },
  error = function(e)
  {
    # error handler picks up where error was generated
    print(paste("ERROR: ", e))
    storeToFile(e, errorFile())
    stop(e) # re-throw the exception
  }
)
