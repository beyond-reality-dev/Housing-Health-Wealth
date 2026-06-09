# Load necessary libraries
library(tidyverse)
library(tidycensus)

# 1. Get and set the Census API Key from the census.key file
CENSUS_API_KEY <- readLines("../census.key")
census_api_key(CENSUS_API_KEY, install = TRUE, overwrite = TRUE)

# 2. Load the NHGIS Block Group-to-Tract Crosswalk
crosswalk_bg <- read_csv(
  "../data/raw/nhgis_bg2010_tr2020_24.csv",
  col_types = cols(
    bg2010ge = "c", 
    tr2020ge = "c", 
    wt_hh    = "d"
    )
 ) |> 
  select(GEOID10_BG = bg2010ge, GEOID20_TR = tr2020ge, weight = wt_hh)

# 3. Define the variables to pull from the ACS
years <- 2016:2024

# Base variables (counts that can be summed across block groups)
vars_base <- c(
  # Denominators
  total_pop          = "B01003_001", total_households   = "B25003_001",
  total_owners_m     = "B25081_001", total_owners_nm    = "B25081_008",
  total_renters      = "B25003_003", vacant_count       = "B25004_001",
  vacant_seasonal    = "B25004_006",
  
  # Cost Burden: Renters
  renter_total       = "B25070_001", renter_30_34       = "B25070_007",
  renter_35_39       = "B25070_008", renter_40_49       = "B25070_009",
  renter_50_plus     = "B25070_010", renter_not_comp    = "B25070_011",
  
  # Cost Burden: Owners with Mortgage
  owner_m_total      = "B25091_002", owner_m_30_34      = "B25091_008",
  owner_m_35_39      = "B25091_009", owner_m_40_49      = "B25091_010",
  owner_m_50_plus    = "B25091_011", owner_m_not_comp   = "B25091_012",
  
  # Cost Burden: Owners without Mortgage
  owner_nm_total     = "B25091_013", owner_nm_30_34     = "B25091_019",
  owner_nm_35_39     = "B25091_020", owner_nm_40_49     = "B25091_021",
  owner_nm_50_plus   = "B25091_022", owner_nm_not_comp  = "B25091_023",
  
  # Overcrowding
  occ_total          = "B25014_001", occ_own_total      = "B25014_002",
  occ_own_1_01_1_50  = "B25014_005", occ_own_1_51_2_00  = "B25014_006",
  occ_own_2_01_plus  = "B25014_007", occ_rnt_total      = "B25014_008",
  occ_rnt_1_01_1_50  = "B25014_011", occ_rnt_1_51_2_00  = "B25014_012",
  occ_rnt_2_01_plus  = "B25014_013",
  
  # Facilities
  plumb_total        = "B25048_001", plumb_lacking      = "B25048_003",
  kitchen_total      = "B25052_001", kitchen_lacking    = "B25052_003"
)

# Year Structure Built Bins (Stable from 2016-2019)
bldg_bins <- c(
  built_2014_later   = "B25034_002", built_2010_2013    = "B25034_003",
  built_2000_2009    = "B25034_004", built_1990_1999    = "B25034_005",
  built_1980_1989    = "B25034_006", built_1970_1979    = "B25034_007",
  built_1960_1969    = "B25034_008", built_1950_1959    = "B25034_009",
  built_1940_1949    = "B25034_010", built_1939_earlier = "B25034_011"
)

# Variable groups for API calls
vars_2020_plus <- c(vars_base, med_tenure = "B25039_001", med_building_age = "B25035_001")
vars_2010s     <- c(vars_base, med_tenure = "B25039_001", bldg_bins)

# 4. Interpolate block group-level data to tracts and generate the annual panel
# Bounds for the building age bins
bin_defs <- tibble(
  bin_name = names(bldg_bins),
  lower = c(2014, 2010, 2000, 1990, 1980, 1970, 1960, 1950, 1940, 1900),
  upper = c(2019, 2013, 2009, 1999, 1989, 1979, 1969, 1959, 1949, 1939)
) |> mutate(width = (upper - lower) + 1)

# Linear Interpolation Function for Medians
calc_interpolated_median <- function(counts, bounds_df) {
  total <- sum(counts, na.rm = TRUE)
  if (total == 0 || is.na(total)) return(NA_real_)
  
  target_pos <- total / 2
  cum_counts <- cumsum(counts)
  med_idx <- which(cum_counts >= target_pos)[1]
  
  if (is.na(med_idx)) return(NA_real_)
  
  L <- bounds_df$lower[med_idx]
  W <- bounds_df$width[med_idx]
  F_val <- counts[med_idx]
  CF <- if (med_idx == 1) 0 else cum_counts[med_idx - 1]
  
  return(L + ((target_pos - CF) / F_val) * W)
}

# 5. Pull and process ACS data for each year, applying interpolation and crosswalking as needed
pull_acs_data <- function(year, xwalk_bg) {
  message(paste("Pulling data for year:", year))
  
  if (year >= 2020) {
    # 2020+: Tract boundaries match. Pull directly.
    return(
      get_acs(geography = "tract", state = "MD", year = year, 
              variables = vars_2020_plus, output = "wide", show_call = FALSE) |> 
        mutate(year = year)
    )
  } else {
    # 2016-2019: Pull Block Groups and crosswalk to 2020 Tracts
    raw_bg <- get_acs(geography = "block group", state = "MD", year = year, 
                      variables = vars_2010s, output = "wide", show_call = FALSE)
    
    crosswalked <- raw_bg |>
      inner_join(xwalk_bg, by = c("GEOID" = "GEOID10_BG")) |>
      mutate(
        # 1. Nullify Census suppression codes (e.g., -666666666) before math
        med_tenureE = if_else(med_tenureE < 1900, NA_real_, med_tenureE),
        
        # 2. Multiply by weight only if data exists
        weighted_med_tenure = med_tenureE * weight,
        
        # 3. Track the weight of valid data for the denominator
        valid_weight_tenure = if_else(!is.na(med_tenureE), weight, 0)
      ) |>
      group_by(GEOID = GEOID20_TR) |>
      summarise(
        across(c(ends_with("E"), -NAME, -med_tenureE), sum, na.rm = TRUE),
        
        # 4. Safe weighted average calculation
        sum_wt_tenure = sum(valid_weight_tenure, na.rm = TRUE),
        med_tenureE = if_else(
          sum_wt_tenure > 0,
          sum(weighted_med_tenure, na.rm = TRUE) / sum_wt_tenure,
          NA_real_
        ),
        .groups = "drop"
      ) |>
      select(-sum_wt_tenure) |> # Drop the helper column
      mutate(year = year)
    
    # Calculate Interpolated Median Building Age from the crosswalked bins
    crosswalked_with_medians <- crosswalked |>
      mutate(
        med_building_ageE = pmap_dbl(
          list(built_2014_laterE, built_2010_2013E, built_2000_2009E, 
               built_1990_1999E, built_1980_1989E, built_1970_1979E, 
               built_1960_1969E, built_1950_1959E, built_1940_1949E, 
               built_1939_earlierE),
          ~ calc_interpolated_median(c(...), bin_defs)
        )
      ) |>
      select(-starts_with("built_"))
    
    return(crosswalked_with_medians)
  }
}
raw_acs_data <- map_dfr(years, ~pull_acs_data(.x, crosswalk_bg))

# 6. Calculate derived variables (cost burden, overcrowding, etc.) from the raw ACS data
calc_cost_burden <- function(df) {
  df |>
    mutate(
      renter_denominator = renter_totalE - renter_not_compE,
      renter_mod_count = renter_30_34E + renter_35_39E + renter_40_49E,
      renter_sev_count = renter_50_plusE,
      owner_denominator = (owner_m_totalE + owner_nm_totalE) - (owner_m_not_compE + owner_nm_not_compE),
      owner_mod_count = owner_m_30_34E + owner_m_35_39E + owner_m_40_49E + owner_nm_30_34E + owner_nm_35_39E + owner_nm_40_49E,
      owner_sev_count = owner_m_50_plusE + owner_nm_50_plusE,
      total_households = renter_denominator + owner_denominator,
      pct_moderate_cost_burden = ((renter_mod_count + owner_mod_count) / total_households) * 100,
      pct_severe_cost_burden = ((renter_sev_count + owner_sev_count) / total_households) * 100
    ) |>
    select(GEOID, year, pct_moderate_cost_burden, pct_severe_cost_burden)
}

calc_tenure <- function(df) {
  df |>
    mutate(
      # Clean 2020+ suppression codes and any leftover zero-sums
      clean_med_tenure = if_else(med_tenureE < 1900 | med_tenureE > year, NA_real_, med_tenureE),
      clean_med_bldg = if_else(med_building_ageE < 1800 | med_building_ageE > year, NA_real_, med_building_ageE),
      
      # Safely calculate the final metrics
      med_tenure = year - clean_med_tenure,
      med_building_age = year - clean_med_bldg
    ) |>
    select(GEOID, year, med_tenure, med_building_age)
}

calc_overcrowding <- function(df) {
  df |>
    mutate(
      overcrowded_count = occ_own_1_01_1_50E + occ_rnt_1_01_1_50E,
      severely_overcrowded_count = occ_own_1_51_2_00E + occ_own_2_01_plusE + occ_rnt_1_51_2_00E + occ_rnt_2_01_plusE,
      pct_overcrowded = (overcrowded_count / occ_totalE) * 100,
      pct_severely_overcrowded = (severely_overcrowded_count / occ_totalE) * 100
    ) |>
    select(GEOID, year, pct_overcrowded, pct_severely_overcrowded)
}

calc_facilities <- function(df) {
  df |>
    mutate(
      pct_lacking_plumbing = (plumb_lackingE / plumb_totalE) * 100,
      pct_lacking_kitchen  = (kitchen_lackingE / kitchen_totalE) * 100
    ) |>
    select(GEOID, year, pct_lacking_plumbing, pct_lacking_kitchen)
}

# 7. Compile and export the final ACS dataset with all derived variables
dfdenominators <- raw_acs_data |>
  mutate(
    true_vacant = if_else(vacant_seasonalE > 0, vacant_countE - vacant_seasonalE, vacant_countE)
  ) |>
  select(GEOID, year, total_pop = total_popE, total_households = total_householdsE, 
         total_owners_m = total_owners_mE, total_owners_nm = total_owners_nmE, 
         total_renters = total_rentersE, total_vacant = true_vacant)

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
  reduce(left_join, by = c("GEOID", "year")) |>
  mutate(
    is_low_pop = total_households < 50 | is.na(total_households),
    across(
      c(starts_with("pct_"), starts_with("med_")),
      ~ if_else(is_low_pop, NA_real_, .x)
    )
  ) |>
    select(-is_low_pop)

output_file <- "../data/clean/acs_data.csv"
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_file)) {
  file.remove(output_file)
}
write_csv(clean_acs_data, output_file)