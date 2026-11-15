# R equivalents of the active acquisition, extraction, and analytic-data stages
# in 04_code/study.py. Existing immutable source bytes are reused by default.

source(file.path("R", "00_config.R"))

download_if_missing <- function(url, destination, expected_prefix = NULL) {
  if (file.exists(destination) && file.info(destination)$size > 0) return("existing")
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  temporary <- tempfile(tmpdir = dirname(destination), fileext = ".download")
  on.exit(unlink(temporary), add = TRUE)
  utils::download.file(url, temporary, mode = "wb", quiet = FALSE)
  if (!is.null(expected_prefix)) {
    connection <- file(temporary, "rb")
    on.exit(close(connection), add = TRUE)
    prefix <- rawToChar(readBin(connection, "raw", n = nchar(expected_prefix)))
    if (!identical(prefix, expected_prefix)) stop("Unexpected content from ", url)
  }
  if (!file.rename(temporary, destination)) stop("Could not move download into place")
  "downloaded"
}

number <- function(x) {
  x <- gsub("[ ,%]", "", trimws(as.character(x)))
  x[toupper(x) %in% c("", "ND", "NA", "N/A")] <- NA_character_
  suppressWarnings(as.numeric(x))
}

row_mean_present <- function(frame, columns) {
  values <- as.matrix(frame[, columns, drop = FALSE])
  result <- rowMeans(values, na.rm = TRUE)
  result[rowSums(!is.na(values)) == 0] <- NA_real_
  result
}

build_analytic_dataset <- function(
    profile = read_csv(file.path(PY_PROCESSED, "who_cervical_profile_extraction.csv")),
    screening = read_csv(file.path(PY_PROCESSED, "who_gho_screening_2019.csv")),
    world_bank = read_csv(file.path(PY_PROCESSED, "world_bank_covariates.csv"))) {
  stopifnot(!anyDuplicated(profile$iso3), !anyDuplicated(screening$iso3),
            !anyDuplicated(world_bank$iso3))
  frame <- merge(profile, screening, by = "iso3", all.x = TRUE, sort = FALSE)
  frame <- merge(frame, world_bank, by = "iso3", all.x = TRUE, sort = FALSE)

  referral <- c("early_detection_guidance", "referral_system", "pathology", "cancer_centre")
  treatment <- c("management_guidelines", "general_diagnosis_treatment",
                 "cancer_surgery", "chemotherapy", "radiotherapy")
  all_items <- c(referral, treatment)

  frame$referral_diagnosis_score <- row_mean_present(frame, referral)
  frame$referral_items_present <- rowSums(!is.na(frame[, referral, drop = FALSE]))
  frame$invasive_treatment_score <- row_mean_present(frame, treatment)
  frame$treatment_items_present <- rowSums(!is.na(frame[, treatment, drop = FALSE]))
  frame$capacity_items_present <- rowSums(!is.na(frame[, all_items, drop = FALSE]))
  frame$capacity_mean <- row_mean_present(frame, all_items)
  eligible <- frame$capacity_items_present >= 5L & frame$referral_items_present >= 1L &
    frame$treatment_items_present >= 1L
  frame$capacity_mean[!eligible] <- NA_real_
  frame$capacity_weakest <- pmin(frame$referral_diagnosis_score,
                                frame$invasive_treatment_score, na.rm = FALSE)
  frame$capacity_geometric <- sqrt((frame$referral_diagnosis_score + 0.01) *
                                     (frame$invasive_treatment_score + 0.01)) - 0.01
  frame$mortality_rate_per_100000 <- frame$cervical_deaths_2019 /
    frame$female_population_2019 * 100000
  frame$screening_10pp <- frame$screened_last5y_2019 / 10
  frame$capacity_10pct <- frame$capacity_mean * 10
  frame$log_incidence <- ifelse(frame$incidence_asr_2020 > 0,
                               log(frame$incidence_asr_2020), NA_real_)
  frame$log_gdp <- ifelse(frame$gdp_ppp_per_capita > 0,
                         log(frame$gdp_ppp_per_capita), NA_real_)
  frame$log_female_population <- ifelse(frame$female_population_2019 > 0,
                                       log(frame$female_population_2019), NA_real_)
  frame
}

load_or_build_dataset <- function(rebuild = FALSE) {
  if (!rebuild) return(read_csv(file.path(PY_PROCESSED, "analytic_cascade_dataset.csv")))
  build_analytic_dataset()
}

availability_summary <- function(frame) {
  variables <- c(
    "screened_last5y_2019", "ever_screened_2019", "screening_programme",
    "early_detection_guidance", "referral_system", "pathology", "cancer_centre",
    "management_guidelines", "general_diagnosis_treatment", "cancer_surgery",
    "chemotherapy", "radiotherapy", "radiotherapy_units_per_10000",
    "brachytherapy_units_per_10000", "cervical_deaths_2019", "female_population_2019",
    "incidence_asr_2020", "registry_exists", "female_hiv_incidence_per_1000",
    "female_tobacco_prevalence", "gdp_ppp_per_capita", "uhc_service_coverage")
  do.call(rbind, lapply(variables, function(variable) {
    available <- sum(!is.na(frame[[variable]]))
    data.frame(variable, available_n = available,
               missing_n = nrow(frame) - available,
               coverage_pct = round(100 * available / nrow(frame), 1))
  }))
}

complete_case_flow <- function(frame) {
  variables <- c("screened_last5y_2019", "capacity_mean", "cervical_deaths_2019",
                 "female_population_2019", "incidence_asr_2020", "gdp_ppp_per_capita")
  keep <- rep(TRUE, nrow(frame))
  rows <- lapply(variables, function(variable) {
    before <- sum(keep)
    keep <<- keep & !is.na(frame[[variable]])
    data.frame(step = variable, before_n = before, after_n = sum(keep),
               lost_n = before - sum(keep))
  })
  do.call(rbind, rows)
}
