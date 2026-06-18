# --- Housing Stability Index Calculation Script ---
# Household Strain Sub-domain: 50% cost-burden rate (-), 50% median tenure
# Overcrowding Sub-domain: 50% overcrowding rate (-), 50% severe overcrowding rate (-)
# Market Distress Sub-domain: 50% vacancy rate (-), 50% NOI per 1000 owners (-), 50% severe cost-burden rate (-)
# Note: The HSI score is a normalized score from 0 to 100 (and a z-score for benchmarking), where higher scores indicate better housing stability. The sub-domain scores are averaged to create the overall HSI score.

# Load necessary libraries
library(tidyverse)

# 1. Define the custom Min-Max scaling function
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

# 2. Compute the Housing Stability Index
merged_data <- read_csv("../data/clean/merged_panel_data.csv")
hsi_data <- merged_data |>
  # STEP A: Scale Individual Metrics (Same as before)
  group_by(year) |>
  mutate(
    idx_cost_burden         = scale_0_100(pct_moderate_cost_burden, "negative"),
    idx_sev_cost_burden     = scale_0_100(pct_severe_cost_burden, "negative"),
    idx_noi                 = scale_0_100(noi_per_1000_owners, "negative"),
    idx_subsidized          = scale_0_100(pct_subsidized_units, "positive"),
    idx_tenure              = scale_0_100(med_tenure, "positive"),
    idx_vacancy             = scale_0_100(vacancy_rate, "negative"),
    idx_overcrowded         = scale_0_100(pct_overcrowded, "negative"),
    idx_sev_overcrowded     = scale_0_100(pct_severely_overcrowded, "negative"),
    idx_lacking_kitchens    = scale_0_100(pct_lacking_kitchen, "negative"),
    idx_lacking_plumbing    = scale_0_100(pct_lacking_plumbing, "negative")
  ) |>
  ungroup() |>
  
  # STEP B: Switch to rowwise() for horizontal tract-level math
  rowwise() |>
  mutate(
    # 1. Count how many of the 7 unique metrics are missing for this specific tract
    missing_count = sum(is.na(c(idx_cost_burden, idx_sev_cost_burden, idx_noi, 
                                idx_tenure, idx_vacancy, idx_overcrowded, idx_sev_overcrowded))),
    
    score_household_strain = mean(c(
      idx_cost_burden,
      idx_tenure
    ), na.rm = TRUE),
    
    score_overcrowding = mean(c(
      idx_overcrowded, 
      idx_sev_overcrowded
    ), na.rm = TRUE),

    score_market_distress = mean(c(
      idx_vacancy,
      idx_noi,
      idx_sev_cost_burden
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
    hsi_zscore = (hsi_score - mean(hsi_score, na.rm = TRUE)) / sd(hsi_score, na.rm = TRUE)
  ) |>
  ungroup() |>
  
  # Clean up: Drop the temporary calculation columns
  select(-raw_hsi_score, -missing_count)

# 3. Save the final HSI dataset to a CSV file
output_file <- "../data/clean/hsi_data.csv"
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_file)) {
  file.remove(output_file)
}
write_csv(hsi_data, output_file)
