pilotEndpoint <- function() {
  Sys.getenv(x = "PILOT_ENDPOINT", "http://localhost:8100")
}

httpClientLogging <- function() {
  httpClientLogging <- Sys.getenv(x = "PILOT_CLIENT_LOG_LEVEL", "NULL") # real NULL not possible (?!)
  httpClientLogging != "NULL"
}

notifyDone <- function(executionType) {
  logger.debug("notify done with success")
  response <- httr::POST(
    paste(pilotEndpoint(), "/pilot/api/v1/copilot/done", sep = ""),
    body = jsonlite::toJSON(list("success" = TRUE, "executionType" = executionType), auto_unbox = TRUE),
    encode = "json",
    httr::content_type_json(),
    if (httpClientLogging()) httr::verbose(info = TRUE, data_out = TRUE, data_in = TRUE)
  )
}

storeConfiguration <- function(configuration) {
  logger.debug("Storing configuration in pilot: %s", configuration)

  response <- httr::POST(
    paste(pilotEndpoint(), "/pilot/api/v1/copilot/configuration", sep = ""),
    body = jsonlite::toJSON(list("configuration" = configuration), auto_unbox = TRUE),
    encode = "json",
    httr::content_type_json(),
    if (httpClientLogging()) httr::verbose(info = TRUE, data_out = TRUE, data_in = TRUE)
  )

  parsedResponse <- httr::content(response, "parsed")

  if (parsedResponse["success"] == TRUE) {
    newConfiguration = jsonlite::toJSON(parsedResponse[["configuration"]], auto_unbox = TRUE)
    Sys.setenv(CONFIGURATION = newConfiguration)
    logger.debug("Set new configuration environment: %s", newConfiguration)
  } else {
    logger.info("Couldn't store Configuration")
  }
}
