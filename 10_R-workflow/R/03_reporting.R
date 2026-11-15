# Output tables and figures corresponding to the active Python reporting stage.

source(file.path("R", "00_config.R"))

descriptive_summary <- function(frame) {
  variables <- c("screened_last5y_2019", "capacity_mean", "mortality_rate_per_100000",
                 "incidence_asr_2020")
  do.call(rbind, lapply(variables, function(variable) {
    x <- frame[[variable]][!is.na(frame[[variable]])]
    data.frame(variable, n = length(x), mean = mean(x), sd = stats::sd(x),
               median = stats::median(x), q1 = unname(stats::quantile(x, .25)),
               q3 = unname(stats::quantile(x, .75)))
  }))
}

regional_summary <- function(frame) {
  dt <- data.table::as.data.table(frame)
  dt[, .(countries = .N,
         screening_available = sum(!is.na(screened_last5y_2019)),
         median_screening = stats::median(screened_last5y_2019, na.rm = TRUE),
         median_capacity = stats::median(capacity_mean, na.rm = TRUE),
         median_mortality_rate = stats::median(mortality_rate_per_100000, na.rm = TRUE)),
     by = .(who_region, who_region_name)]
}

write_project02_outputs <- function(frame, fits, run_uncertainty = FALSE) {
  write_json(fits$decision, "stop_rule_decision.json")
  if (nrow(fits$coefficients)) write_csv(fits$coefficients, "primary_negative_binomial_coefficients.csv")
  if (nrow(fits$marginal_effects)) write_csv(fits$marginal_effects, "screening_effect_by_capacity.csv")
  write_csv(descriptive_summary(frame), "table_1_descriptive_summary.csv")
  write_csv(regional_summary(frame), "table_2_regional_summary.csv")
  write_csv(availability_summary(frame), "indicator_availability_matrix.csv")
  write_csv(complete_case_flow(frame), "complete_case_flow.csv")
  if (run_uncertainty && !is.null(fits$model)) {
    write_csv(screening_uncertainty(fits$model, fits$sample),
              "screening_uncertainty_propagation.csv")
  }
  invisible(TRUE)
}

make_project02_figures <- function(frame, fits) {
  palette <- c(AFR = "#C0392B", AMR = "#1C7293", EMR = "#B7791F",
               EUR = "#2F855A", SEAR = "#805AD5", WPR = "#065A82")
  plot_frame <- frame[stats::complete.cases(frame[, c("screened_last5y_2019", "capacity_mean")]), ]
  figure <- ggplot2::ggplot(plot_frame,
    ggplot2::aes(screened_last5y_2019, capacity_mean * 100, colour = who_region)) +
    ggplot2::geom_point(alpha = .78, size = 2) +
    ggplot2::scale_colour_manual(values = palette) +
    ggplot2::labs(x = "Women aged 30 to 49 screened in previous 5 years (%)",
                  y = "Downstream capacity score (%)", colour = "WHO region",
                  title = "Joint screening and downstream-capacity distribution") +
    ggplot2::theme_minimal(base_size = 10)
  ggplot2::ggsave(file.path(OUT_DIR, "figure_1_joint_screening_capacity.png"),
                  figure, width = 10, height = 7, dpi = 300)
  invisible(figure)
}
