test_that("linkTable carries one row per location with its coordinates, without geometry", {
  # arrange
  data <- readCase("latlon-three-tracks")

  # act
  actual <- linkTable(data = data)

  # assert
  expect_equal(nrow(actual), 12)
  expect_equal(actual$coords_x, unname(sf::st_coordinates(data)[, 1]))
  expect_equal(actual$coords_y, unname(sf::st_coordinates(data)[, 2]))
  expect_false("geometry" %in% names(actual))
})

test_that("linkTable repeats the track attributes on every row", {
  # arrange
  data <- readCase("latlon-three-tracks")

  # act
  actual <- linkTable(data = data)

  # assert: data.frame() makes the names syntactic, as v2.2.0 did
  expect_true(all(make.names(names(mt_track_data(data))) %in% names(actual)))
})

test_that("linkTable writes sfc attributes as WKT", {
  # arrange
  data <- readCase("argos-sfc")

  # act
  actual <- linkTable(data = data)

  # assert
  expect_type(actual$argos_location_1, "character")
  expect_match(actual$argos_location_1, "^POINT \\(")
})

test_that("linkTable leaves no list column behind", {
  # arrange
  data <- readCase("list-columns")

  # act
  actual <- linkTable(data = data)

  # assert
  expect_false(any(vapply(actual, is.list, logical(1))))
})

test_that("linkTable keeps the milliseconds of a midnight fix", {
  # arrange
  data <- readCase("mollweide-midnight")

  # act
  actual <- linkTable(data = data)

  # assert
  expect_true("2021-12-10 00:00:00.000" %in% actual$timestamp)
})

test_that("linkTable keeps milliseconds below the second", {
  # arrange
  data <- readCase("subsecond")

  # act
  actual <- linkTable(data = data)

  # assert
  expect_equal(actual$timestamp, c("2014-08-06 09:19:35.000", "2014-08-06 09:19:35.999", "2014-08-06 09:19:36.999", "2014-08-06 09:19:38.000"))
})

test_that("linkTable writes UTC instants, whatever the tzone", {
  # arrange
  data <- readCase("berlin")

  # act
  actual <- linkTable(data = data)

  # assert: 06:40 UTC is 08:40 in Berlin; link.csv carries the instant, meta.csv the zone
  expect_equal(actual$timestamp[1], "2021-07-01 06:40:00.000")
})
