#!/usr/bin/env Rscript
# End-to-end R entry point. Outputs remain isolated from the Python results.

source(file.path("R", "00_config.R"))
assert_packages()
source(file.path("R", "01_data.R"))
source(file.path("R", "02_models.R"))
source(file.path("R", "03_reporting.R"))
source(file.path("R", "04_verify.R"))

arguments <- commandArgs(trailingOnly = TRUE)
rebuild <- "--rebuild-data" %in% arguments
uncertainty <- "--uncertainty" %in% arguments
figures <- "--figures" %in% arguments

frame <- load_or_build_dataset(rebuild = rebuild)
fits <- fit_project02_models(frame)
write_project02_outputs(frame, fits, run_uncertainty = uncertainty)
if (figures) make_project02_figures(frame, fits)
parity <- verify_project02_parity(frame, fits)
message("Project 02 R workflow complete: ", parity$status)
