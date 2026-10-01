test_that("linkMeta names crs, tzone, time and track column", {
  # arrange
  data <- readCase("latlon-three-tracks")

  # act
  actual <- linkMeta(data = data)

  # assert
  expect_equal(actual, data.frame(crs = "EPSG:4326", tzone = "UTC", timeColName = "timestamp", trackIdColName = "individual_local_identifier"))
})

test_that("linkMeta keeps the crs of a projected input", {
  # arrange
  data <- readCase("mollweide-midnight")

  # act
  actual <- linkMeta(data = data)

  # assert
  expect_equal(actual$crs, "ESRI:54009")
})

test_that("linkMeta keeps a timezone other than UTC", {
  # arrange
  data <- readCase("berlin")

  # act
  actual <- linkMeta(data = data)

  # assert
  expect_equal(actual$tzone, "Europe/Berlin")
})
