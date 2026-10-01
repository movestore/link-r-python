library("moveapps")
moveapps::logger.init()
source("link.R")

tryCatch(
    {
      Sys.setenv(tz="UTC")

      writeLink(data = moveapps::readInput(moveapps::sourceFile()), bufferFile = Sys.getenv(x = "LINK_R_PYTHON_BUFFER"), metaFile = Sys.getenv(x = "LINK_R_PYTHON_META"))
    },
    error = function(e)
    {
        # error handler picks up where error was generated
        print(paste("ERROR: ", e))
        moveapps::storeToFile(e, moveapps::errorFile())
        stop(e) # re-throw the exception
    }
)
