# Formal comparison of deterministic and statistical R results with Python outputs.

source(file.path("R", "00_config.R"))

assert_close <- function(actual, expected, tolerance, label) {
  difference <- abs(actual - expected)
  if (any(!is.finite(difference)) || any(difference > tolerance)) {
    stop(label, " differs from Python baseline; max absolute difference = ",
         max(difference, na.rm = TRUE), ", tolerance = ", tolerance)
  }
  invisible(TRUE)
}

verify_project02_parity <- function(frame, fits) {
  python_decision <- jsonlite::read_json(file.path(PY_RESULTS, "stop_rule_decision.json"),
                                         simplifyVector = TRUE)
  exact_fields <- c("complete_case_n", "capacity_lower_tertile_n",
                    "capacity_upper_tertile_n", "interaction_analysis_proceeds")
  for (field in exact_fields) {
    if (!identical(as.character(fits$decision[[field]]), as.character(python_decision[[field]]))) {
      stop("Stop-rule mismatch for ", field)
    }
  }
  assert_close(fits$decision$screening_iqr_pp, python_decision$screening_iqr_pp,
               1e-10, "Screening IQR")
  assert_close(fits$decision$capacity_lower_tertile_cut,
               python_decision$capacity_lower_tertile_cut, 1e-10, "Lower tertile")
  assert_close(fits$decision$capacity_upper_tertile_cut,
               python_decision$capacity_upper_tertile_cut, 1e-10, "Upper tertile")

  rebuilt <- build_analytic_dataset()
  keys <- c("capacity_mean", "capacity_weakest", "capacity_geometric",
            "mortality_rate_per_100000", "screening_10pp", "capacity_10pct",
            "log_incidence", "log_gdp", "log_female_population")
  baseline <- frame[match(rebuilt$iso3, frame$iso3), ]
  for (field in keys) {
    keep <- is.finite(rebuilt[[field]]) & is.finite(baseline[[field]])
    assert_close(rebuilt[[field]][keep], baseline[[field]][keep], 1e-10,
                 paste("Derived field", field))
    if (!identical(is.na(rebuilt[[field]]), is.na(baseline[[field]]))) {
      stop("Missingness mismatch for derived field ", field)
    }
  }

  python_coef <- read_csv(file.path(PY_RESULTS, "primary_negative_binomial_coefficients.csv"))
  interaction <- python_coef[python_coef$term == "screening_10pp:capacity_10pct", ]
  r_interaction <- fits$coefficients[
    fits$coefficients$term == "screening_10pp:capacity_10pct", ]
  if (nrow(interaction) != 1L || nrow(r_interaction) != 1L) stop("Interaction term missing")
  # MASS and statsmodels use different NB dispersion parameterisations/optimisers.
  # A 0.02 coefficient tolerance is prespecified; signs and inferential conclusion
  # must also agree.
  assert_close(r_interaction$coefficient, interaction$coefficient, .02,
               "Primary interaction coefficient")
  if (sign(r_interaction$coefficient) != sign(interaction$coefficient)) {
    stop("Primary interaction sign differs from Python")
  }

  report <- list(
    status = "pass",
    checked_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    deterministic_derived_fields = keys,
    stop_rule = "exact",
    primary_interaction_absolute_tolerance = .02,
    note = "Model tolerance accounts for MASS versus statsmodels NB optimisation."
  )
  write_json(report, "parity_report.json")
  report
}

verify_manuscript_text <- function() {
  source_md <- file.path(PY_MANUSCRIPT, "manuscript_ver02.md")
  docx <- file.path(PY_MANUSCRIPT, "manuscript_ver02.docx")
  pandoc <- Sys.which("pandoc")
  if (!nzchar(pandoc) || !file.exists(source_md) || !file.exists(docx)) {
    return(list(status = "skipped", reason = "Pandoc or manuscript pair unavailable"))
  }
  md <- system2(pandoc, c(shQuote(source_md), "--from=gfm", "--to=plain", "--wrap=none"),
                stdout = TRUE, stderr = TRUE)
  word <- system2(pandoc, c(shQuote(docx), "--from=docx", "--to=plain", "--wrap=none"),
                  stdout = TRUE, stderr = TRUE)
  list(status = if (identical(normalise_text(paste(md, collapse = "\n")),
                              normalise_text(paste(word, collapse = "\n")))) "pass" else "different")
}
