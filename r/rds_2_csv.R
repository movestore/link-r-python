source("src/common/logger.R")
source("src/common/runtime_configuration.R")
source("src/io/app_files.R")
source("src/io/io_handler.R")
source("src/io/rds.R")
source("link.R")

tryCatch(
    {
      Sys.setenv(tz="UTC")

      writeLink(data = readInput(sourceFile()), bufferFile = Sys.getenv(x = "LINK_R_PYTHON_BUFFER"), metaFile = Sys.getenv(x = "LINK_R_PYTHON_META"))
    },
    error = function(e)
    {
        # error handler picks up where error was generated
        print(paste("ERROR: ", e))
        storeToFile(e, errorFile())
        stop(e) # re-throw the exception
    }
)
