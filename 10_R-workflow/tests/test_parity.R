# Base-R test runner so parity checks do not depend on testthat.

source(file.path("R", "00_config.R"))
assert_packages()
source(file.path("R", "01_data.R"))
source(file.path("R", "02_models.R"))
source(file.path("R", "04_verify.R"))

stopifnot(identical(number("12.5%"), 12.5))
stopifnot(is.na(number("ND")))

frame <- load_or_build_dataset(FALSE)
stopifnot(nrow(frame) == 194L, !anyDuplicated(frame$iso3))
fits <- fit_project02_models(frame)
stopifnot(isTRUE(fits$decision$interaction_analysis_proceeds))
verify_project02_parity(frame, fits)
message("Project 02 tests passed")
