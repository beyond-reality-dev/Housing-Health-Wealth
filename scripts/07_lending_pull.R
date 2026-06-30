# Load necessary libraries
library(tidyverse)

# 1. Pull HMDA data
target_years <- 2018:2024
for (year in target_years) {
  url <- paste0("https://ffiec.cfpb.gov/v2/data-browser-api/view/csv?years=", year, "&states=MD")
  data <- read_csv(url, show_col_types = FALSE)
  data <- data |>
    mutate(
      year = year,
      census_tract = str_pad(census_tract, width = 11, side = "left", pad = "0")
    ) |>
    select(year, census_tract, action_taken, loan_purpose, loan_amount, loan_to_value_ratio, occupancy_type, derived_dwelling_category)
  
  output_file <- paste0("../data/raw/lending/hmda_data_", year, ".csv")
  dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(output_file)) {
    file.remove(output_file)
  }
  write_csv(data, output_file)
}

# 2. Organize CRA data
for (year in target_years) {
  # Unzip the CRA data file for the year
  zip_file <- paste0("../data/raw/lending/cra_data_", year, ".zip")
  unzip(zip_file, exdir = paste0("../data/raw/lending/cra_data_", year))
  file.rename(
    from = paste0("../data/raw/lending/cra_data_", year, "/cra", year, "_Aggr_A11.dat"),
    to = paste0("../data/raw/lending", "/cra", year, "_Aggr_A11.dat")
  )
}
file.remove(list.files("../data/raw/lending", pattern = "cra_data_", full.names = TRUE, recursive = TRUE))

# 3. Load the Maryland Tract Relationship Data and identify stable pre-2020 tracts
url <- "https://www2.census.gov/geo/docs/maps-data/data/rel2020/tract/tab20_tract20_tract10_st24.txt"
dest <- "../data/raw/md_tract_relationship.txt"
if (!file.exists(dest)) download.file(url, dest)
rel <- read_delim(dest, delim = "|", col_types = cols(.default = "c"))

rel <- rel %>%
  mutate(across(starts_with("AREALAND"), as.numeric),
         # Share of the 2020 tract's area that came from this 2010 tract
         pct_of_2020 = AREALAND_PART / AREALAND_TRACT_20,
         # Share of the 2010 tract's area that went into this 2020 tract
         pct_of_2010 = AREALAND_PART / AREALAND_TRACT_10)

n_sources <- rel %>% count(GEOID_TRACT_20, name = "n_2010_sources")
n_targets <- rel %>% count(GEOID_TRACT_10, name = "n_2020_targets")

rel <- rel %>%
  left_join(n_sources, by = "GEOID_TRACT_20") %>%
  left_join(n_targets, by = "GEOID_TRACT_10")

stable_tracts <- rel %>%
  filter(n_2010_sources == 1,
         pct_of_2020 >= 0.99,
         pct_of_2010 >= 0.99) %>%
  distinct(GEOID_TRACT_20)

all_tracts_classified <- rel %>%
  group_by(GEOID_TRACT_20) %>%
  mutate(n_records = n()) %>%
  ungroup() %>%
  mutate(
    stability_class = case_when(
      GEOID_TRACT_20 %in% stable_tracts$GEOID_TRACT_20 ~ "Stable",
      n_records == 1 & (pct_of_2020 <= 0.99 | pct_of_2010 <= 0.99) ~ "Minor boundary change",
      n_records > 1  & n_2010_sources > 1 & n_2020_targets == 1     ~ "Merge (many-to-one)",
      n_records > 1  & n_2010_sources == 1 & n_2020_targets > 1     ~ "Split (one-to-many)",
      TRUE                                                            ~ "Complex change"
    )
  ) %>%
  distinct(GEOID_TRACT_20, stability_class)

# 3. Combine all years of HMDA and CRA data and crosswalk pre-2022 tracts to 2020 boundaries
hmda_raw <- target_years |>
  map_dfr(~ read_csv(paste0("../data/raw/lending/hmda_data_", .x, ".csv"), show_col_types = FALSE)) |>
  mutate(
    year      = as.integer(year),
    GEOID     = as.character(census_tract)
  ) |>
  select(year, GEOID, action_taken, loan_purpose, loan_amount, loan_to_value_ratio, occupancy_type, derived_dwelling_category)

cra_raw <- target_years |>
  map_dfr(~ read_fwf(paste0("../data/raw/lending/cra", .x, "_Aggr_A11.dat"),
                     fwf_positions(
                      start = c(1, 6, 10, 11, 12, 14, 17, 22, 29, 30, 31, 34, 37, 47, 57, 67, 77, 87, 97, 107, 117), 
                      end = c(5, 9, 10, 11, 13, 16, 21, 28, 29, 30, 33, 36, 46, 56, 66, 76, 86, 96, 106, 116, 145),
                      col_names = c("table_id", "year", "loan_type", "action_taken_type", "state", "county", "msa",
                        "census_tract", "split_county_indicator", "population_classification",
                        "income_group_total", "report_level", "num_sbl_under100k", "total_sbl_under100k",
                        "num_sbl_100k_250k", "total_sbl_100k_250k", "num_sbl_250k_1m", "total_sbl_250k_1m",
                        "num_sbl", "total_sbl", "filler")
                      ),
                     col_types = cols(.default = "c"))) |>
  mutate(
    year      = as.integer(year),
    state_code = as.character(state),
    county_code = as.character(county),
    census_tract = str_remove(census_tract, fixed(".")),
    GEOID     = paste0(state_code, county_code, census_tract),
    num_sbl = as.integer(num_sbl),
    total_sbl = as.integer(total_sbl)
  ) |>
  select(year, state_code, GEOID, num_sbl, total_sbl) |>
  filter(state_code == "24")

eligible_2020_hmda <- all_tracts_classified |>
  filter(stability_class %in% c("Stable", "Minor boundary change", "Merge (many-to-one)"))

merge_source_counts_hmda <- rel |>
  inner_join(
    eligible_2020_hmda |> filter(stability_class == "Merge (many-to-one)"),
    by = "GEOID_TRACT_20"
  ) |>
  count(GEOID_TRACT_20, name = "n_sources")

eligible_2020_hmda <- eligible_2020_hmda |>
  left_join(merge_source_counts_hmda, by = "GEOID_TRACT_20") |>
  mutate(n_sources = replace_na(n_sources, 1)) |>
  filter(!(stability_class == "Merge (many-to-one)" & n_sources > 2))

xwalk <- rel |>
  inner_join(eligible_2020_hmda, by = "GEOID_TRACT_20") |>
  distinct(GEOID_TRACT_10, GEOID_TRACT_20)

crosswalk_to_2020 <- function(df, pre_year = 2022) {
  bind_rows(
    df |> filter(year >= pre_year),
    df |>
      filter(year < pre_year) |>
      inner_join(xwalk, by = c("GEOID" = "GEOID_TRACT_10")) |>
      mutate(GEOID = GEOID_TRACT_20) |>
      select(-GEOID_TRACT_20)
  )
}

hmda_data <- crosswalk_to_2020(hmda_raw)
cra_data <- crosswalk_to_2020(cra_raw)

# 4. Calculate the mortgage origination rate, mortgage denial rate, and refinance denial rate for each tract and year
acs_data <- read_csv("../data/clean/acs_data.csv", show_col_types = FALSE)
acs_data <- acs_data |> 
  mutate(GEOID = as.character(GEOID)) |> 
  select(GEOID, year, total_households) |> 
  filter(year %in% target_years)

hmda <- hmda_data |>
  filter(
      occupancy_type == 1,
      derived_dwelling_category == "Single Family (1-4 Units):Site-Built",
    ) |>
  group_by(year, GEOID) |> 
  mutate(loan_to_value_ratio = as.numeric(loan_to_value_ratio)) |>
  summarise(
    home_purchase_loans  = sum(loan_purpose == 1, na.rm = TRUE),
    loan_totals          = sum(loan_amount, na.rm = TRUE),
    refinance_loans      = sum(loan_purpose == 31, na.rm = TRUE),
    purchase_denials     = sum(loan_purpose == 1 & action_taken == 3, na.rm = TRUE),
    refinance_denials    = sum(loan_purpose == 31 & action_taken == 3, na.rm = TRUE),
    originated_loans     = sum(loan_purpose == 1 & action_taken == 1, na.rm = TRUE),
    median_loan_to_value = median(loan_to_value_ratio[loan_purpose == 1 & action_taken == 1], na.rm = TRUE),
    .groups = "drop"
  ) |> 
  right_join(acs_data, by = c("GEOID", "year")) |>
  mutate(
    across(
      c(home_purchase_loans, refinance_loans, purchase_denials, refinance_denials, originated_loans),
      \(x) if_else(is.na(x), 0, x)
    )
  ) |> 
  mutate(
    mortgage_origination_rate  = if_else(is.na(total_households) | total_households == 0, NA_real_, originated_loans / total_households),
    refinance_origination_rate = if_else(is.na(total_households) | total_households == 0, NA_real_, refinance_loans / total_households),
    mortgage_denial_rate       = if_else(home_purchase_loans == 0, NA_real_, purchase_denials / home_purchase_loans),
    refinance_denial_rate      = if_else(refinance_loans == 0, NA_real_, refinance_denials / refinance_loans),
    home_loan_amount_per_household = if_else(is.na(total_households) | total_households == 0, NA_real_, loan_totals / total_households)
  )

cra <- cra_data |>
  group_by(year, GEOID) |> 
  summarise(
    small_business_loans       = sum(num_sbl, na.rm = TRUE),
    small_business_loans_total = sum(total_sbl, na.rm = TRUE),
    .groups = "drop"
  ) |> 
  right_join(acs_data, by = c("GEOID", "year")) |> 
  mutate(
    small_business_loans       = if_else(is.na(small_business_loans), 0, small_business_loans),
    small_business_loans_total = if_else(is.na(small_business_loans_total), 0, small_business_loans_total)
  ) |> 
  mutate(
    small_business_loan_rate = if_else(
      is.na(total_households) | total_households == 0, 
      NA_real_, 
      small_business_loans / total_households
    ),
    small_business_loan_amount_per_household = if_else(
      is.na(total_households) | total_households == 0, 
      NA_real_, 
      small_business_loans_total / total_households
    )
  ) |> 
  select(year, GEOID, small_business_loan_rate, small_business_loan_amount_per_household)
combined_data <- hmda |>
  left_join(cra, by = c("GEOID", "year")) |>
  select(year, GEOID, mortgage_origination_rate, refinance_origination_rate, mortgage_denial_rate, refinance_denial_rate, home_loan_amount_per_household, small_business_loan_rate, small_business_loan_amount_per_household, median_loan_to_value)

# 5. Save the final dataset to a CSV file
output_file <- "../data/clean/lending_data.csv"
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_file)) {
  file.remove(output_file)
}
write_csv(combined_data, output_file)
