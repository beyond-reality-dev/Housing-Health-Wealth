# Load necessary libraries
library(tidyverse)

# 1. Define the Socrata API endpoint for the NOI data
noi_url <- "https://opendata.maryland.gov/resource/nme2-wik5.csv?$limit=1500"

# 2. Pull the dataset
raw_noi_data <- read_csv(noi_url, show_col_types = FALSE)

# 3. Clean and reshape from wide to long (panel) format
clean_noi_data <- raw_noi_data %>%
  pivot_longer(
    cols = -geoid20,
    names_to = "year",
    values_to = "total_noi"
  ) %>%
  mutate(
    year = as.numeric(str_extract(year, "\\d{4}")),
    GEOID = as.character(geoid20),
    total_noi = as.numeric(total_noi)
  ) %>%
  select(GEOID, year, total_noi)

# 4. Read ACS mortgaged-owner counts for proportional allocation
acs_data <- read_csv("../data/clean/acs_data.csv", show_col_types = FALSE) %>%
  mutate(GEOID = as.character(GEOID))

# 5. Define statewide NOI totals by year
state_totals <- tibble(
  year = c(2022, 2023, 2024, 2025),
  state_total_noi = c(55671, 66580, 79577, 91076)
)

# 6. Join ACS weights and allocate suppressed counts
noi_weighted <- clean_noi_data %>%
  left_join(
    acs_data %>%
      select(GEOID, year, total_owners_m),
    by = c("GEOID", "year")
  ) %>%
  left_join(state_totals, by = "year") %>%
  group_by(year) %>%
  mutate(
    observed_noi_total = sum(total_noi, na.rm = TRUE),
    missing_noi_total = pmax(state_total_noi - observed_noi_total, 0),
    suppressed_weight = if_else(is.na(total_noi), coalesce(total_owners_m, 0), 0),
    suppressed_weight_total = sum(suppressed_weight, na.rm = TRUE),
    suppressed_noi_allocation = if_else(
      is.na(total_noi) & suppressed_weight_total > 0,
      missing_noi_total * suppressed_weight / suppressed_weight_total,
      0
    ),
    final_imputed_noi = case_when(
      !is.na(total_noi) ~ total_noi,
      is.na(total_noi) & suppressed_weight_total > 0 ~ pmin(suppressed_noi_allocation, 9),
      TRUE ~ NA_real_
    ),
    noi_per_1000_owners = (final_imputed_noi / total_owners_m) * 1000
  ) %>%
  ungroup() %>%
  select(GEOID, year, total_noi, total_owners_m, state_total_noi, observed_noi_total, missing_noi_total, final_imputed_noi, noi_per_1000_owners)

# 7. Save the cleaned NOI data to a CSV file
output_file <- "../data/clean/noi_data.csv"
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_file)) {
  file.remove(output_file)
}

write_csv(noi_weighted %>% select(GEOID, year, total_noi = final_imputed_noi, noi_per_1000_owners), output_file)
