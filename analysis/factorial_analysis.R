# ============================================================
# Paper Airplane Factorial Design
# ============================================================

library(ggplot2)
library(dplyr)
library(readr)

# ------------------------------------------------------------
# Load data
# ------------------------------------------------------------

initial_experiment <- read_csv(
  "data/initial_experiment.csv",
  show_col_types = FALSE
)

redesigned_experiment <- read_csv(
  "data/redesigned_experiment.csv",
  show_col_types = FALSE
)

# ------------------------------------------------------------
# Prepare initial experiment
# ------------------------------------------------------------

initial_experiment <- initial_experiment %>%
  mutate(
    design = recode(
      design,
      "zip" = "Zip Dart",
      "jet" = "Jet Fighter"
    ),
    mean_distance = rowMeans(
      across(c(I, II, III))
    )
  )

# ------------------------------------------------------------
# Prepare redesigned experiment
# ------------------------------------------------------------

redesigned_experiment <- redesigned_experiment %>%
  rename(
    run_order = `run order`,
    stored_mean = mean
  ) %>%
  mutate(
    design_name = case_when(
      design == -1 ~ "Zip Dart",
      design == 1 ~ "Jet Fighter"
    ),
    angle_degrees = case_when(
      angle == -1 ~ 30,
      angle == 0 ~ 45,
      angle == 1 ~ 60
    ),
    paper_weight = case_when(
      paper == -1 ~ 20,
      paper == 1 ~ 24
    ),
    experiment_stage = if_else(
      angle == 0,
      "Angle center runs",
      "Factorial runs"
    ),
    mean_distance = rowMeans(
      across(c(I, II, III))
    )
  )

# ------------------------------------------------------------
# Verify imported data
# ------------------------------------------------------------

cat("\nInitial experiment:\n")
print(initial_experiment)

cat("\nRedesigned experiment:\n")
print(redesigned_experiment)

cat("\nMaximum difference between stored and recalculated means:\n")
print(
  max(
    abs(
      redesigned_experiment$stored_mean -
        redesigned_experiment$mean_distance
    )
  )
)

# ------------------------------------------------------------
# Initial experiment: variability assessment
# ------------------------------------------------------------

initial_variability <- initial_experiment %>%
  mutate(
    range_distance = pmax(I, II, III) - pmin(I, II, III),
    sd_distance = apply(
      select(., I, II, III),
      1,
      sd
    )
  ) %>%
  select(
    design,
    angle,
    paper,
    mean_distance,
    range_distance,
    sd_distance
  )

cat("\nInitial experiment variability by treatment combination:\n")
print(initial_variability)

cat("\nOverall initial experiment variability:\n")
cat(
  "Mean within-treatment standard deviation:",
  mean(initial_variability$sd_distance),
  "\n"
)
cat(
  "Mean within-treatment range:",
  mean(initial_variability$range_distance),
  "\n"
)
cat(
  "Largest within-treatment range:",
  max(initial_variability$range_distance),
  "\n"
)

# ------------------------------------------------------------
# Redesigned experiment: variability assessment
# ------------------------------------------------------------

redesigned_variability <- redesigned_experiment %>%
  mutate(
    range_distance = pmax(I, II, III) - pmin(I, II, III),
    sd_distance = apply(
      select(., I, II, III),
      1,
      sd
    )
  ) %>%
  select(
    design_name,
    angle_degrees,
    paper_weight,
    experiment_stage,
    mean_distance,
    range_distance,
    sd_distance
  )

factorial_variability <- redesigned_variability %>%
  filter(experiment_stage == "Factorial runs")

cat("\nRedesigned factorial variability by treatment combination:\n")
print(factorial_variability)

cat("\nOverall redesigned factorial variability:\n")
cat(
  "Mean within-treatment standard deviation:",
  mean(factorial_variability$sd_distance),
  "\n"
)
cat(
  "Mean within-treatment range:",
  mean(factorial_variability$range_distance),
  "\n"
)
cat(
  "Largest within-treatment range:",
  max(factorial_variability$range_distance),
  "\n"
)

cat("\nChange in variability after redesign:\n")
cat(
  "Percent reduction in mean within-treatment standard deviation:",
  100 * (
    1 -
      mean(factorial_variability$sd_distance) /
      mean(initial_variability$sd_distance)
  ),
  "%\n"
)
cat(
  "Percent reduction in mean within-treatment range:",
  100 * (
    1 -
      mean(factorial_variability$range_distance) /
      mean(initial_variability$range_distance)
  ),
  "%\n"
)

# ------------------------------------------------------------
# Redesigned experiment: 2^3 factorial effects
# ------------------------------------------------------------

factorial_data <- redesigned_experiment %>%
  filter(experiment_stage == "Factorial runs")

factorial_model <- lm(
  mean_distance ~ design * angle * paper,
  data = factorial_data
)

factorial_coefficients <- coef(factorial_model)

factorial_effects <- tibble(
  term = c(
    "Design",
    "Angle",
    "Paper",
    "Design × Angle",
    "Design × Paper",
    "Angle × Paper",
    "Design × Angle × Paper"
  ),
  effect = 2 * c(
    factorial_coefficients["design"],
    factorial_coefficients["angle"],
    factorial_coefficients["paper"],
    factorial_coefficients["design:angle"],
    factorial_coefficients["design:paper"],
    factorial_coefficients["angle:paper"],
    factorial_coefficients["design:angle:paper"]
  )
) %>%
  mutate(
    absolute_effect = abs(effect)
  ) %>%
  arrange(desc(absolute_effect))

cat("\nEstimated factorial effects:\n")
print(factorial_effects)

cat("\nGrand mean of factorial runs:\n")
print(unname(factorial_coefficients["(Intercept)"]))

# ------------------------------------------------------------
# Effect screening: half normal plot
# ------------------------------------------------------------

half_normal_data <- factorial_effects %>%
  arrange(absolute_effect) %>%
  mutate(
    rank = row_number(),
    half_normal_quantile = qnorm(
      0.5 + 0.5 * ((rank - 0.5) / n())
    )
  )

half_normal_plot <- ggplot(
  half_normal_data,
  aes(
    x = half_normal_quantile,
    y = absolute_effect,
    label = term
  )
) +
  geom_point(size = 3) +
  geom_text(
    nudge_x = 0.04,
    nudge_y = 0.5,
    hjust = 0,
    size = 3.5
  ) +
  labs(
    title = "Half Normal Plot of Factorial Effects",
    x = "Half normal quantile",
    y = "Absolute effect"
  ) +
  scale_x_continuous(
    expand = expansion(mult = c(0.05, 0.18))
  ) +
  coord_cartesian(clip = "off") +
  theme_minimal(base_size = 12) +
  theme(
    plot.margin = margin(
      t = 10,
      r = 55,
      b = 10,
      l = 10
    )
  )

print(half_normal_plot)

# ------------------------------------------------------------
# Effect screening: Lenth's method
# ------------------------------------------------------------

absolute_effects <- factorial_effects$absolute_effect

# Initial scale estimate
s0 <- 1.5 * median(absolute_effects)

# Retain effects smaller than 2.5 * s0
small_effects <- absolute_effects[
  absolute_effects < 2.5 * s0
]

# Pseudo standard error
pse <- 1.5 * median(small_effects)

# Number of estimated effects
m <- length(absolute_effects)

# Approximate pseudo degrees of freedom
df_lenth <- m / 3

# Individual margin of error
margin_error <- qt(
  0.975,
  df = df_lenth
) * pse

lenth_results <- factorial_effects %>%
  mutate(
    exceeds_margin = absolute_effect > margin_error
  )

cat("\nLenth effect screening:\n")
cat("Initial scale estimate (s0):", s0, "\n")
cat("Pseudo standard error (PSE):", pse, "\n")
cat("Margin of error:", margin_error, "\n")

print(lenth_results)

# ------------------------------------------------------------
# Reduced factorial model
# ------------------------------------------------------------

reduced_model <- lm(
  mean_distance ~ design + angle + paper +
    design:angle + angle:paper,
  data = factorial_data
)

cat("\nReduced factorial model:\n")
print(summary(reduced_model))

cat("\nANOVA table for reduced model:\n")
print(anova(reduced_model))

# ------------------------------------------------------------
# Reduced model diagnostics
# ------------------------------------------------------------

diagnostic_data <- tibble(
  fitted = fitted(reduced_model),
  residual = resid(reduced_model),
  standardized_residual = rstandard(reduced_model)
)

cat("\nReduced model diagnostic values:\n")
print(diagnostic_data)

# Residuals versus fitted values
residual_plot <- ggplot(
  diagnostic_data,
  aes(x = fitted, y = residual)
) +
  geom_hline(
    yintercept = 0,
    linetype = "dashed"
  ) +
  geom_point(size = 3) +
  labs(
    title = "Residuals Versus Fitted Values",
    x = "Fitted flight distance",
    y = "Residual"
  ) +
  theme_minimal(base_size = 12)

print(residual_plot)

# Normal Q-Q plot
qq_plot <- ggplot(
  diagnostic_data,
  aes(sample = standardized_residual)
) +
  stat_qq(size = 3) +
  stat_qq_line() +
  labs(
    title = "Normal Q-Q Plot of Standardized Residuals",
    x = "Theoretical quantiles",
    y = "Standardized residuals"
  ) +
  theme_minimal(base_size = 12)

print(qq_plot)

# ------------------------------------------------------------
# Curvature assessment using 45-degree angle runs
# ------------------------------------------------------------

curvature_model <- lm(
  mean_distance ~ design + angle + paper +
    design:angle + angle:paper +
    I(angle^2),
  data = redesigned_experiment
)

cat("\nModel including quadratic angle term:\n")
print(summary(curvature_model))

cat("\nANOVA table for model including quadratic angle term:\n")
print(anova(curvature_model))

cat("\nEstimated quadratic angle coefficient:\n")
print(coef(curvature_model)["I(angle^2)"])

# ------------------------------------------------------------
# Interaction summaries and plots
# ------------------------------------------------------------

design_angle_summary <- factorial_data %>%
  group_by(design_name, angle_degrees) %>%
  summarise(
    mean_distance = mean(mean_distance),
    .groups = "drop"
  )

angle_paper_summary <- factorial_data %>%
  group_by(angle_degrees, paper_weight) %>%
  summarise(
    mean_distance = mean(mean_distance),
    .groups = "drop"
  )

cat("\nDesign by angle interaction means:\n")
print(design_angle_summary)

cat("\nAngle by paper interaction means:\n")
print(angle_paper_summary)

# Design by angle interaction
design_angle_plot <- ggplot(
  design_angle_summary,
  aes(
    x = angle_degrees,
    y = mean_distance,
    group = design_name,
    linetype = design_name,
    shape = design_name
  )
) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 3) +
  scale_x_continuous(
    breaks = c(30, 60)
  ) +
  labs(
    title = "Interaction Between Plane Design and Launch Angle",
    x = "Launch angle (degrees)",
    y = "Mean flight distance (inches)",
    linetype = "Plane design",
    shape = "Plane design"
  ) +
  theme_minimal(base_size = 12)

print(design_angle_plot)

# Angle by paper interaction
angle_paper_plot <- ggplot(
  angle_paper_summary,
  aes(
    x = angle_degrees,
    y = mean_distance,
    group = factor(paper_weight),
    linetype = factor(paper_weight),
    shape = factor(paper_weight)
  )
) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 3) +
  scale_x_continuous(
    breaks = c(30, 60)
  ) +
  labs(
    title = "Interaction Between Launch Angle and Paper Weight",
    x = "Launch angle (degrees)",
    y = "Mean flight distance (inches)",
    linetype = "Paper weight (lb)",
    shape = "Paper weight (lb)"
  ) +
  theme_minimal(base_size = 12)

print(angle_paper_plot)