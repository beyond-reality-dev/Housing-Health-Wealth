# Load necessary libraries
library(tidyverse)
library(tidycensus)

# Get and set the Census API Key from the census.key file
CENSUS_API_KEY <- readLines("../census.key")
census_api_key(CENSUS_API_KEY, install = TRUE, overwrite = TRUE)

# Define the variables to pull from the ACS
years <- 2020:2024
vars_denominators <- c(
  total_pop          = "B01003_001", # Total population
  total_households   = "B25003_001", # Total occupied housing units
  total_owners_m     = "B25081_001", # Owner-occupied units with a mortgage
  total_owners_nm    = "B25081_008", # Owner-occupied units without a mortgage
  total_renters      = "B25003_003" # Renter-occupied housing units
)
vars_cost_burden <- c(
  # Renters (B25070)
  renter_total       = "B25070_001", # Total renter-occupied units
  renter_30_34       = "B25070_007", # Renters paying 30-34.9% of income on rent
  renter_35_39       = "B25070_008", # Renters paying 35-39.9% of income on rent
  renter_40_49       = "B25070_009", # Renters paying 40-49.9% of income on rent
  renter_50_plus     = "B25070_010", # Renters paying >=50% of income on rent
  renter_not_comp    = "B25070_011", # Renters with missing cost burden data

  # Owners with Mortgage (B25091)
  owner_m_total      = "B25091_002", # Total owner-occupied with mortgage
  owner_m_30_34      = "B25091_008", # Mortgages costing 30-34.9% of income
  owner_m_35_39      = "B25091_009", # Mortgages costing 35-39.9% of income
  owner_m_40_49      = "B25091_010", # Mortgages costing 40-49.9% of income
  owner_m_50_plus    = "B25091_011", # Mortgages costing >=50% of income
  owner_m_not_comp   = "B25091_012", # Mortgages with missing cost burden data

  # Owners without Mortgage (B25091)
  owner_nm_total     = "B25091_013", # Total owner-occupied without mortgage
  owner_nm_30_34     = "B25091_019", # Ownership costs of 30-34.9% of income
  owner_nm_35_39     = "B25091_020", # Ownership costs of 35-39.9% of income
  owner_nm_40_49     = "B25091_021", # Ownership costs of 40-49.9% of income
  owner_nm_50_plus   = "B25091_022", # Ownership costs of >=50% of income
  owner_nm_not_comp  = "B25091_023" # Ownership with missing cost burden data
)
vars_tenure <- c(
  med_tenure = "B25039_001", # Median year household moved into unit
  med_building_age = "B25035_001", # Median year structure built
  total_vacant = "B25004_001" # Total housing units
)
vars_overcrowding <- c(
  occ_total          = "B25014_001", # total occupied units
  occ_own_total      = "B25014_002", # total owner-occupied
  occ_own_1_01_1_50  = "B25014_005", # overcrowded (owner)
  occ_own_1_51_2_00  = "B25014_006", # severely overcrowded (owner)
  occ_own_2_01_plus  = "B25014_007", # severely overcrowded (owner)
  occ_rnt_total      = "B25014_008", # total renter-occupied
  occ_rnt_1_01_1_50  = "B25014_011", # overcrowded (renter)
  occ_rnt_1_51_2_00  = "B25014_012", # severely overcrowded (renter)
  occ_rnt_2_01_plus  = "B25014_013" # severely overcrowded (renter)
)
vars_facilities <- c(
  plumb_total = "B25048_001", # Total occupied units (plumbing facilities)
  plumb_lacking = "B25048_003", # Units lacking complete plumbing facilities
  kitchen_total = "B25052_001", # Total occupied units (kitchen facilities)
  kitchen_lacking = "B25052_003" # Units lacking complete kitchen facilities
)

variables_to_pull <- c(
  vars_denominators,
  vars_cost_burden,
  vars_tenure,
  vars_overcrowding,
  vars_facilities
)

# Create function to pull ACS data for a single ACS year
pull_acs_data <- function(year) {
  get_acs(
    geography = "tract",
    state = "MD",
    year = year,
    variables = variables_to_pull,
    output = "wide"
  ) %>%
    mutate(year = year)
}

# Pull ACS data for all specified years and combine into a single data frame
raw_acs_data <- map_dfr(years, pull_acs_data)

# Moderately cost burdened: 30-49% of income;
# Severely cost burdened: 50% or more of income
calc_cost_burden <- function(df) {
  df |>
    mutate(
      renter_denominator = renter_totalE - renter_not_compE,
      renter_mod_count = renter_30_34E + renter_35_39E + renter_40_49E,
      renter_sev_count = renter_50_plusE,
      owner_denominator = (owner_m_totalE + owner_nm_totalE) -
        (owner_m_not_compE + owner_nm_not_compE),
      owner_mod_count = owner_m_30_34E + owner_m_35_39E + owner_m_40_49E +
        owner_nm_30_34E + owner_nm_35_39E + owner_nm_40_49E,
      owner_sev_count = owner_m_50_plusE + owner_nm_50_plusE,
      total_households = renter_denominator + owner_denominator,
      pct_moderate_cost_burden = ((renter_mod_count + owner_mod_count) /
        total_households) * 100,
      pct_severe_cost_burden = ((renter_sev_count + owner_sev_count) /
        total_households) * 100
    ) |>
    select(GEOID, year, pct_moderate_cost_burden, pct_severe_cost_burden)
}

# Calculate median tenure in years
calc_tenure <- function(df) {
  df |>
    mutate(
      med_tenure = year - med_tenureE,
      # If median building age is not a plausible year, set to NA
      med_building_age = if_else(
        med_building_ageE < 1800 | med_building_ageE > year,
        NA_real_,
        year - med_building_ageE
      )
    ) |>
    select(GEOID, year, med_tenure, med_building_age, total_vacant = total_vacantE)
}

# Overcrowding: >1.01 persons/room; severe: >1.50 persons/room
calc_overcrowding <- function(df) {
  df |>
    mutate(
      overcrowded_count = occ_own_1_01_1_50E + occ_rnt_1_01_1_50E,
      severely_overcrowded_count = occ_own_1_51_2_00E + occ_own_2_01_plusE +
        occ_rnt_1_51_2_00E + occ_rnt_2_01_plusE,
      pct_overcrowded = (overcrowded_count / occ_totalE) * 100,
      pct_severely_overcrowded = (severely_overcrowded_count / occ_totalE) * 100
    ) |>
    select(GEOID, year, pct_overcrowded, pct_severely_overcrowded)
}

# Housing quality: share of occupied units lacking complete
# plumbing or kitchen facilities
calc_facilities <- function(df) {
  df |>
    mutate(
      pct_lacking_plumbing = (plumb_lackingE / plumb_totalE) * 100,
      pct_lacking_kitchen  = (kitchen_lackingE / kitchen_totalE) * 100
    ) |>
    select(GEOID, year, pct_lacking_plumbing, pct_lacking_kitchen)
}

# Compute all metrics and combine into a single data frame
dfdenominators <- raw_acs_data |>
  select(
    GEOID,
    year,
    total_popE,
    total_householdsE,
    total_owners_mE,
    total_owners_nmE,
    total_rentersE
  ) |>
  rename(
    total_pop = total_popE,
    total_households = total_householdsE,
    total_owners_m = total_owners_mE,
    total_owners_nm = total_owners_nmE,
    total_renters = total_rentersE
  )
dfcost_burden <- calc_cost_burden(raw_acs_data)
dftenure <- calc_tenure(raw_acs_data)
dfovercrowding <- calc_overcrowding(raw_acs_data)
dffacilities <- calc_facilities(raw_acs_data)

clean_acs_data <- list(
  dfdenominators,
  dfcost_burden,
  dftenure,
  dfovercrowding,
  dffacilities
) |>
  reduce(left_join, by = c("GEOID", "year"))

output_file <- "../data/clean/acs_data.csv"

# Make sure the output folder exists when the script is run from scripts/
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)

# Delete existing file if it exists to avoid appending to old data
if (file.exists(output_file)) {
  file.remove(output_file)
}

# Save the cleaned ACS data to a CSV file
write_csv(clean_acs_data, output_file)
