test_that("readLink returns NULL for a buffer without rows", {
  # arrange
  buffer <- writeTempLines("timestamp_utc,track,coords_x,coords_y")

  # act
  actual <- readLink(bufferFile = buffer, metaFile = metaFileFor())

  # assert
  expect_null(actual)
})

test_that("readLink builds a move2 in the crs of meta.csv, ordered by track and time", {
  # arrange
  buffer <- writeTempLines(c(
    "timestamp_utc,track,coords_x,coords_y",
    "2021-07-01 06:46:00,b,1,2",
    "2021-07-01 06:40:00,b,3,4",
    "2021-07-01 06:40:00,a,5,6"
  ))

  # act
  actual <- readLink(bufferFile = buffer, metaFile = metaFileFor())

  # assert
  expect_true(mt_is_move2(actual))
  expect_equal(sf::st_crs(actual), sf::st_crs("EPSG:4326"))
  expect_equal(as.character(mt_track_id(actual)), c("a", "b", "b"))
  expect_equal(format(mt_time(actual), "%H:%M"), c("06:40", "06:40", "06:46"))
})

test_that("readLink reads the times in the tzone of meta.csv", {
  # arrange
  buffer <- writeTempLines(c(
    "timestamp_utc,track,coords_x,coords_y",
    "2021-07-01 06:40:00,a,1,2",
    "2021-07-01 06:46:00,a,1,2"
  ))

  # act
  actual <- readLink(bufferFile = buffer, metaFile = metaFileFor(tzone = "Asia/Kolkata"))

  # assert: 06:40 in Kolkata (UTC+05:30) is 01:10 UTC
  expect_equal(attr(mt_time(actual), "tzone"), "Asia/Kolkata")
  expect_equal(format(mt_time(actual)[1], "%Y-%m-%d %H:%M:%S", tz = "UTC"), "2021-07-01 01:10:00")
})

test_that("readLink truncates sub-second times (v2.2.0, pinned)", {
  # arrange
  buffer <- writeTempLines(c(
    "timestamp_utc,track,coords_x,coords_y",
    "2021-07-01 06:40:00.123,a,1,2",
    "2021-07-01 06:40:01.000,a,1,2"
  ))

  # act
  actual <- readLink(bufferFile = buffer, metaFile = metaFileFor())

  # assert
  expect_equal(as.numeric(mt_time(actual))[1] %% 1, 0)
})

test_that("readLink leaves python's True and False as text (v2.2.0, pinned)", {
  # arrange
  buffer <- writeTempLines(c(
    "timestamp_utc,track,coords_x,coords_y,visible",
    "2021-07-01 06:40:00,a,1,2,True",
    "2021-07-01 06:46:00,a,1,2,False"
  ))

  # act
  actual <- readLink(bufferFile = buffer, metaFile = metaFileFor())

  # assert
  expect_equal(actual$visible, c("True", "False"))
})

test_that("readLink returns NULL for an empty buffer file", {
  # arrange: python writes one for an empty TrajectoryCollection
  buffer <- tempfile(fileext = ".csv")
  file.create(buffer)
  meta <- tempfile(fileext = ".csv")
  file.create(meta)

  # act
  actual <- readLink(bufferFile = buffer, metaFile = meta)

  # assert
  expect_null(actual)
})
