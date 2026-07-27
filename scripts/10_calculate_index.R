# --- Housing Stability Index Calculation ---
# The Housing Stability Index is calculated as a weighted average of three sub-domains:
# Household Strain Sub-domain: 50% cost-burden rate (-), 50% median tenure
# Overcrowding Sub-domain: 50% overcrowding rate (-), 50% severe overcrowding rate (-)
# Market Distress Sub-domain: 33% vacancy rate (-), 33% NOI per 1000 owners (-), 33% severe cost-burden rate (-)
# Note: The HSI score is a normalized score from 0 to 100 (and a z-score for benchmarking), where higher scores indicate better housing stability. The sub-domain scores are averaged to create the overall HSI score.
#
# --- Health Outcomes Index Calculation ---
# The health outcomes index is calculated as the average of five percentile ranks: 
# Uninsurance rates | Pre-1980 housing (proxy for lead paint risk) | Low birth weight | Asthma | Myocardial infarction 
# Each of these metrics is scaled from 0 to 100, where higher scores indicate better health outcomes.
#
# --- Displacement Risk Assessment Calculation ---
# If a tract has a z-score for minority population change < -0.5, it receives 1 point.
# If a tract has a z-score for educational attainment change > 0.5, it receives 1 point.
# If a tract has a z-score for school withdrawal rate change > 1, it receives 1 point.
# The total points are summed to create a displacement risk score (0-3), which is then categorized as follows:
# 0 points: Stable | 1 point: Low | 2 points: Moderate | 3 points: Severe
#
# --- Wealth Accumulation Index Calculation ---
# The wealth Accumulation Index is calculated as a weighted average of three sub-domains:
# Economic Stability Sub-domain: 25% homeownership rate (+), 25% median household income (+), 
#                                25% poverty rate (-), 25% unemployment rate (-)
# Home Assets Sub-domain: 50% median home price (+), 50% appreciation rate (+)
# Capital Access Sub-domain: 50% small business loan rate (+), 50% small business loan amount per household (+)
# Note: The WAI score is a normalized score from 0 to 100 (and a z-score for benchmarking), where higher scores indicate better wealth accumulation.

# Load necessary libraries
library(tidyverse)
library(dplyr)

# 1. Define the custom scaling functions
z_score <- function(x, direction = "positive") {
  mean_x <- mean(x, na.rm = TRUE)
  sd_x <- sd(x, na.rm = TRUE)
  
  # Prevent division by zero while preserving NA values
  if (!is.na(sd_x) && sd_x == 0) {
    x[!is.na(x)] <- 0
    return(x)
  }
  
  if (direction == "negative") {
    return((mean_x - x) / sd_x)
  } else {
    return((x - mean_x) / sd_x)
  }
}
scale_0_100 <- function(x, direction = "positive") {
  min_x <- min(x, na.rm = TRUE)
  max_x <- max(x, na.rm = TRUE)
  
  # Prevent division by zero if all values in a year are identical
  if(min_x == max_x) return(rep(50, length(x))) 
  
  if (direction == "negative") {
    return(((max_x - x) / (max_x - min_x)) * 100)
  } else {
    return(((x - min_x) / (max_x - min_x)) * 100)
  }
}
winsorize <- function(x, lower_quantile = 0.01, upper_quantile = 0.99) {
  lower_bound <- quantile(x, lower_quantile, na.rm = TRUE)
  upper_bound <- quantile(x, upper_quantile, na.rm = TRUE)
  x[x < lower_bound] <- lower_bound
  x[x > upper_bound] <- upper_bound
  return(x)
}

# 2. Compute the Housing Stability Index
merged_data <- read_csv("../data/clean/merged_panel_data.csv")
hsi_data <- merged_data |>
  # STEP A: Scale individual metrics
  group_by(year) |>
  mutate(across(c(pct_moderate_cost_burden, pct_severe_cost_burden, noi_per_1000_owners, pct_subsidized_units, med_tenure, vacancy_rate, pct_overcrowded, pct_severely_overcrowded, pct_lacking_kitchen, pct_lacking_plumbing, med_building_age), 
         ~winsorize(.x))) |>
  mutate(
    z_cost_burden             = z_score(pct_moderate_cost_burden, "negative"),
    z_sev_cost_burden         = z_score(pct_severe_cost_burden, "negative"),
    z_noi                     = z_score(noi_per_1000_owners, "negative"),
    z_subsidized              = z_score(pct_subsidized_units, "positive"),
    z_tenure                  = z_score(med_tenure, "positive"),
    z_vacancy                 = z_score(vacancy_rate, "negative"),
    z_overcrowded             = z_score(pct_overcrowded, "negative"),
    z_sev_overcrowded         = z_score(pct_severely_overcrowded, "negative"),
    z_lacking_kitchens        = z_score(pct_lacking_kitchen, "negative"),
    z_lacking_plumbing        = z_score(pct_lacking_plumbing, "negative"),
    z_bldg_age                = z_score(med_building_age, "negative"),
    idx_uninsurance           = percent_rank(pct_uninsured) * 100,
    idx_pre_1980_housing      = percent_rank(pct_built_pre1980) * 100,
    idx_low_birth_weight      = percentile_low_birth_weight,
    idx_asthma                = percentile_asthma,
    idx_myocardial_infarction = percentile_myocardial_infarction
  ) |>
  ungroup() |>
  
  # STEP B: Switch to rowwise() for horizontal tract-level math
  rowwise() |>
  mutate(
    # 1. Count how many of the 7 unique metrics are missing for this specific tract
    missing_count = sum(is.na(c(z_cost_burden, z_sev_cost_burden, z_noi, 
                                z_tenure, z_vacancy, z_overcrowded, z_sev_overcrowded))),
    
    # 2. Calculate the sub-domain scores by averaging the relevant indices
    score_household_strain = mean(c(
      z_cost_burden,
      z_sev_cost_burden,
      z_tenure
    ), na.rm = TRUE),
    
    score_overcrowding = mean(c(
      z_overcrowded,
      z_sev_overcrowded
    ), na.rm = TRUE),

    score_market_distress = mean(c(
      z_vacancy,
      z_noi
    ), na.rm = TRUE),
    
    # 3. Calculate the preliminary overall score
    raw_hsi_score = mean(c(
      score_household_strain,
      score_overcrowding,
      score_market_distress
      ), na.rm = TRUE),

    # 4. If a tract is missing 3 or more variables, we force the final score to NA.
    hsi_score = case_when(
      missing_count >= 3 ~ NA_real_,
      is.nan(raw_hsi_score) ~ NA_real_,
      TRUE ~ raw_hsi_score
    )
  ) |>
  ungroup() |>
  
  # STEP C: Calculate the Z-Score relative to the year, strictly on the surviving tracts
  group_by(year) |>
  mutate(
    hsi_percentile = percent_rank(hsi_score) * 100,
    idx_hsi_score  = scale_0_100(hsi_score, "positive")
  ) |>
  ungroup() |>
  
  # Clean up: Drop the temporary calculation columns
  select(-raw_hsi_score, -missing_count)

# STEP D: Compute the PCA loadings for the 2022 base year to validate the HSI sub-domains
pca_vars <- c("z_cost_burden", "z_sev_cost_burden", "z_noi", 
              "z_tenure", "z_vacancy", "z_overcrowded", "z_sev_overcrowded")
data_2022 <- hsi_data |>
  filter(year == 2022) |>
  drop_na(all_of(pca_vars))
pca_model_2022 <- prcomp(data_2022[, pca_vars], center = TRUE, scale. = TRUE)
print(summary(pca_model_2022))
loadings <- pca_model_2022$rotation
print(loadings)

# 3. Compute the Displacement Risk Assessment
hsi_data <- hsi_data |>
  group_by(year) |>
  mutate(
    zscore_change_minority = (pct_pt_change_minority - mean(pct_pt_change_minority, na.rm = TRUE)) / sd(pct_pt_change_minority, na.rm = TRUE),
    zscore_change_education = (pct_pt_change_education - mean(pct_pt_change_education, na.rm = TRUE)) / sd(pct_pt_change_education, na.rm = TRUE),
    zscore_change_churn = (change_in_churn - mean(change_in_churn, na.rm = TRUE)) / sd(change_in_churn, na.rm = TRUE)
  ) |>
  ungroup() |>
  mutate(
    displacement_score = 
    coalesce(as.integer(zscore_change_minority < -0.5), 0) +
    coalesce(as.integer(zscore_change_education > 0.5), 0) +
    coalesce(as.integer(zscore_change_churn > 1), 0),
    displacement_category = case_when(
      displacement_score == 0 ~ "Stable",
      displacement_score == 1 ~ "Low",
      displacement_score == 2 ~ "Moderate",
      displacement_score == 3 ~ "Severe",
      TRUE ~ "Unknown"
    )
  )

# 4. Compute the Health Outcomes Index
hsi_data <- hsi_data |>
  rowwise() |>
  mutate(
    missing_health_metrics = sum(is.na(c(idx_uninsurance, idx_pre_1980_housing, idx_low_birth_weight, idx_asthma, idx_myocardial_infarction))),
    health_outcomes_index = mean(c(
      idx_uninsurance,
      idx_pre_1980_housing,
      idx_low_birth_weight,
      idx_asthma,
      idx_myocardial_infarction
    ), na.rm = TRUE),
    health_outcomes_index = if_else(missing_health_metrics >= 3, NA_real_, 100 - health_outcomes_index),
  ) |>
  ungroup() |>
  mutate(
    hoi_score = percent_rank(health_outcomes_index) * 100
  )

# 5. Compute the Wealth Accumulation Index
wealth_data <- merged_data |>
# STEP A: Scale individual metrics
  group_by(year) |>
  mutate(across(c(pct_homeowners, median_hh_income, pct_poverty, pct_unemployed, mortgage_origination_rate, refinance_origination_rate, mortgage_denial_rate, refinance_denial_rate, home_loan_amount_per_household, small_business_loan_rate, small_business_loan_amount_per_household, median_loan_to_value, median_sale_price, appreciation_rate), 
         ~winsorize(.x))) |>
  mutate(
      z_pct_homeownership = z_score(pct_homeowners, "positive"),
      z_median_income = z_score(median_hh_income, "positive"),
      z_percent_poverty = z_score(pct_poverty, "negative"),
      z_percent_unemployed = z_score(pct_unemployed, "negative"),
      z_mortgage_origination_rate = z_score(mortgage_origination_rate, "positive"),
      z_refinance_origination_rate = z_score(refinance_origination_rate, "positive"),
      z_mortgage_denial_rate = z_score(mortgage_denial_rate, "negative"),
      z_refinance_denial_rate = z_score(refinance_denial_rate, "negative"),
      z_home_loan_amt = z_score(home_loan_amount_per_household, "positive"),
      z_small_business_loan_rate = z_score(small_business_loan_rate, "positive"),
      z_small_business_loan_amount_per_household = z_score(small_business_loan_amount_per_household, "positive"),
      z_median_loan_to_value = z_score(median_loan_to_value, "negative"),
      z_median_home_price = z_score(median_sale_price, "positive"),
      z_appreciation_rate = z_score(appreciation_rate, "positive")
    ) |>
  ungroup() |>
  
  # STEP B: Switch to rowwise() for horizontal tract-level math
  rowwise() |>
  mutate(
    # 1. Missingness count across the 9 core variables
    missing_count = sum(is.na(c(z_pct_homeownership, z_median_income, z_percent_poverty, z_percent_unemployed, 
                                z_small_business_loan_rate, z_small_business_loan_amount_per_household, 
                                z_median_home_price, z_appreciation_rate))),
    
    # 2. Calculate Sub-domain scores
    score_stability = mean(c(z_pct_homeownership, z_median_income, z_percent_poverty, z_percent_unemployed), na.rm = TRUE),
    score_assets    = mean(c(z_median_home_price, z_appreciation_rate), na.rm = TRUE),
    score_capital   = mean(c(z_small_business_loan_rate, z_small_business_loan_amount_per_household), na.rm = TRUE),

    # 3. Calculate preliminary overall score (based on PCA loadings and weights)
    raw_wealth_score = 0.5 * score_stability + 0.25 * score_assets + 0.25 * score_capital,

    # 4. Enforce missingness threshold (e.g., NA if missing 4 or more)
    wealth_score = case_when(
      missing_count >= 4 ~ NA_real_,
      is.nan(raw_wealth_score) ~ NA_real_,
      TRUE ~ raw_wealth_score
    )
  ) |>
  ungroup() |>

  # STEP C: Calculate the final relative Z-Score and Percentile by year
  group_by(year) |>
  mutate(
    wealth_percentile = percent_rank(wealth_score) * 100,
    idx_wealth_score  = scale_0_100(wealth_score, "positive")
  ) |>
  ungroup() |>
  
  select(-raw_wealth_score, -missing_count)

# STEP D: Compute the PCA loadings for the 2022 base year to validate the WAI sub-domains
pca_vars <- c("z_pct_homeownership", "z_median_income", "z_percent_poverty", "z_percent_unemployed", 
              "z_small_business_loan_rate", "z_small_business_loan_amount_per_household", 
              "z_median_home_price", "z_appreciation_rate")
data_2022 <- wealth_data |>
  filter(year == 2022) |>
  drop_na(all_of(pca_vars))
pca_model_2022 <- prcomp(data_2022[, pca_vars], center = TRUE, scale. = TRUE)
print(summary(pca_model_2022))
loadings <- pca_model_2022$rotation
print(loadings)


hsi_data <- hsi_data |>
  left_join(wealth_data |> select(GEOID, year, wealth_score, idx_wealth_score, wealth_percentile), by = c("GEOID", "year"))

# 6. Save the final HSI dataset to a CSV file
output_file <- "../data/clean/hsi_data.csv"
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_file)) {
  file.remove(output_file)
}
write_csv(hsi_data, output_file)
