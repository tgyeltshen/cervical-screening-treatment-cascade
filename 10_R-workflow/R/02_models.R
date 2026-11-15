# Negative-binomial interaction model and prespecified sensitivity analyses.

source(file.path("R", "00_config.R"))

model_columns <- c("cervical_deaths_2019", "log_female_population", "screening_10pp",
                   "capacity_10pct", "log_incidence", "log_gdp", "who_region",
                   "registry_exists")

analysis_sample <- function(frame) {
  frame[stats::complete.cases(frame[, model_columns, drop = FALSE]), , drop = FALSE]
}

stop_rule <- function(sample) {
  screen_iqr <- diff(stats::quantile(sample$screened_last5y_2019, c(.25, .75), type = 7))
  cuts <- stats::quantile(sample$capacity_mean, c(1 / 3, 2 / 3), type = 7)
  lower_n <- sum(sample$capacity_mean <= cuts[[1]])
  upper_n <- sum(sample$capacity_mean >= cuts[[2]])
  list(
    complete_case_n = nrow(sample),
    screening_iqr_pp = unname(screen_iqr),
    capacity_lower_tertile_cut = unname(cuts[[1]]),
    capacity_upper_tertile_cut = unname(cuts[[2]]),
    capacity_lower_tertile_n = lower_n,
    capacity_upper_tertile_n = upper_n,
    interaction_analysis_proceeds = nrow(sample) >= 80 && screen_iqr >= 10 &&
      lower_n >= 10 && upper_n >= 10,
    decision_rule = "n>=80, screening IQR>=10 pp, at least 10 countries in each capacity tertile"
  )
}

primary_formula <- cervical_deaths_2019 ~ screening_10pp * capacity_10pct +
  log_incidence + log_gdp + registry_exists + factor(who_region)

fit_negative_binomial <- function(sample, formula = primary_formula) {
  MASS::glm.nb(formula, data = sample, offset = log_female_population,
               control = stats::glm.control(maxit = 500, epsilon = 1e-10))
}

tidy_model <- function(model, robust = TRUE) {
  covariance <- if (robust) hc3(model) else stats::vcov(model)
  beta <- stats::coef(model)
  se <- sqrt(diag(covariance))
  z <- beta / se
  data.frame(
    term = names(beta), coefficient = unname(beta), se_robust = unname(se),
    rate_ratio = exp(unname(beta)), ci_low = exp(unname(beta - 1.96 * se)),
    ci_high = exp(unname(beta + 1.96 * se)),
    p_value = 2 * stats::pnorm(abs(z), lower.tail = FALSE), check.names = FALSE)
}

marginal_screening_effects <- function(model, sample) {
  covariance <- hc3(model)
  beta <- stats::coef(model)
  interaction <- "screening_10pp:capacity_10pct"
  capacities <- stats::quantile(sample$capacity_mean, c(.25, .50, .75), type = 7)
  labels <- c("Low capacity", "Median capacity", "High capacity")
  do.call(rbind, Map(function(label, capacity) {
    scaled <- capacity * 10
    effect <- beta[["screening_10pp"]] + scaled * beta[[interaction]]
    variance <- covariance["screening_10pp", "screening_10pp"] +
      scaled^2 * covariance[interaction, interaction] +
      2 * scaled * covariance["screening_10pp", interaction]
    se <- sqrt(max(variance, 0))
    data.frame(capacity_level = label, capacity_score = unname(capacity),
               screening_rate_ratio_per_10pp = exp(effect),
               ci_low = exp(effect - 1.96 * se), ci_high = exp(effect + 1.96 * se))
  }, labels, as.list(capacities)))
}

fit_project02_models <- function(frame) {
  sample <- analysis_sample(frame)
  decision <- stop_rule(sample)
  if (!decision$interaction_analysis_proceeds) {
    return(list(decision = decision, sample = sample, model = NULL,
                coefficients = data.frame(), marginal_effects = data.frame()))
  }
  model <- fit_negative_binomial(sample)
  list(decision = decision, sample = sample, model = model,
       coefficients = tidy_model(model),
       marginal_effects = marginal_screening_effects(model, sample))
}

screening_uncertainty <- function(model, sample, iterations = 200L, seed = SEED) {
  set.seed(seed)
  sigma <- pmax((sample$screened_last5y_2019_high - sample$screened_last5y_2019_low) / 3.92, .25)
  interaction <- numeric(iterations)
  theta <- model$theta
  for (index in seq_len(iterations)) {
    simulated <- sample
    simulated$screened_last5y_2019 <- pmin(100, pmax(0,
      stats::rnorm(nrow(sample), sample$screened_last5y_2019, sigma)))
    simulated$screening_10pp <- simulated$screened_last5y_2019 / 10
    fitted <- MASS::glm.nb(primary_formula, data = simulated,
                           offset = log_female_population, init.theta = theta,
                           control = stats::glm.control(maxit = 200))
    interaction[[index]] <- stats::coef(fitted)[["screening_10pp:capacity_10pct"]]
  }
  data.frame(iterations, interaction_median = stats::median(interaction),
             interaction_p2_5 = unname(stats::quantile(interaction, .025)),
             interaction_p97_5 = unname(stats::quantile(interaction, .975)),
             note = "Propagation of WHO screening-estimate uncertainty only; not a full inferential interval")
}
