# Project 02 paths, reproducibility controls, and small shared utilities.

locate_workflow_root <- function(start = getwd()) {
  path <- normalizePath(start, winslash = "/", mustWork = TRUE)
  repeat {
    if (basename(path) == "10_R-workflow") return(path)
    candidate <- file.path(path, "10_R-workflow")
    if (dir.exists(candidate)) return(normalizePath(candidate, winslash = "/"))
    parent <- dirname(path)
    if (identical(parent, path)) stop("Cannot locate 10_R-workflow")
    path <- parent
  }
}

WORKFLOW_ROOT <- locate_workflow_root()
PROJECT_ROOT <- normalizePath(dirname(WORKFLOW_ROOT), winslash = "/")
R_DIR <- file.path(WORKFLOW_ROOT, "R")
OUT_DIR <- file.path(WORKFLOW_ROOT, "outputs")
PY_PROCESSED <- file.path(PROJECT_ROOT, "03_processed_data")
PY_RESULTS <- file.path(PROJECT_ROOT, "05_results")
PY_TABLES <- file.path(PROJECT_ROOT, "07_tables")
PY_MANUSCRIPT <- file.path(PROJECT_ROOT, "08_manuscript")
SEED <- 20260814L

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

required_packages <- c("data.table", "ggplot2", "jsonlite", "MASS", "sandwich")

assert_packages <- function(packages = required_packages) {
  missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing)) {
    stop("Missing R packages: ", paste(missing, collapse = ", "),
         ". Restore with renv::restore().")
  }
  invisible(TRUE)
}

read_csv <- function(path) data.table::fread(path, na.strings = c("", "NA", "NaN"), data.table = FALSE)

write_csv <- function(x, filename) {
  path <- file.path(OUT_DIR, filename)
  data.table::fwrite(x, path, na = "")
  path
}

write_json <- function(x, filename) {
  path <- file.path(OUT_DIR, filename)
  jsonlite::write_json(x, path, pretty = TRUE, auto_unbox = TRUE, na = "null", digits = 16)
  path
}

hc3 <- function(model) sandwich::vcovHC(model, type = "HC3")

normalise_text <- function(x) {
  x <- gsub("\u00a0", " ", x, fixed = TRUE)
  x <- gsub("[\u2013\u2212]", "-", x)
  trimws(gsub("\\s+", " ", x, perl = TRUE))
}

mode_value <- function(x) {
  x <- x[!is.na(x)]
  names(sort(table(x), decreasing = TRUE))[1]
}
