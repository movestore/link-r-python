# the CSV pair between R and python, pinned by the goldens the v2.2.0 production images produced
bytesOf <- function(file) readBin(file, what = "raw", n = file.size(file))

for (case in contractCases) {
  test_that(sprintf("writeLink reproduces the v2.2.0 CSV pair of '%s' byte for byte", case), {
    # arrange
    buffer <- tempfile(fileext = ".csv")
    meta <- tempfile(fileext = ".csv")

    # act
    writeLink(data = readCase(case), bufferFile = buffer, metaFile = meta)

    # assert
    expect_identical(bytesOf(meta), bytesOf(file.path(contractDir, case, "meta.csv")))
    expect_identical(bytesOf(buffer), bytesOf(file.path(contractDir, case, "link.csv")))
  })

  test_that(sprintf("readLink turns python's CSV pair of '%s' back into its locations", case), {
    # arrange: python keeps only the tracks with at least two fixes
    input <- readCase(case)

    # act
    actual <- readLink(bufferFile = file.path(contractDir, case, "py", "link.csv"), metaFile = file.path(contractDir, case, "py", "meta.csv"))

    # assert: times to the millisecond, as an absolute difference - expect_equal's tolerance is
    # relative, and at 1.4e9 seconds even its default forgives 20 seconds
    kept <- input[as.character(mt_track_id(input)) %in% as.character(mt_track_id(actual)), ]
    expect_equal(nrow(actual), nrow(kept))
    expect_equal(sf::st_crs(actual), sf::st_crs(input))
    expect_lt(max(abs(sort(as.numeric(mt_time(actual))) - sort(as.numeric(mt_time(kept))))), 5e-4)
  })
}
