# Load necessary libraries
library(tidyverse)
library(tidycensus)

# 1. Get and set the Census API Key from the census.key file
CENSUS_API_KEY <- readLines("../census.key")
census_api_key(CENSUS_API_KEY, install = TRUE, overwrite = TRUE)

# 2. Load the Maryland Tract Relationship Data and identify stable pre-2020 tracts
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

# 3. Define the variables to pull from the ACS
years <- 2010:2024

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
  kitchen_total      = "B25052_001", kitchen_lacking    = "B25052_003",

  # Group housing
  grp_hsg_total      = "B26001_001",

  # Demographics
  white              = "B02001_002", total_educated     = "B15002_001",
  m_bachelor_degree  = "B15002_015", m_masters_degree   = "B15002_016",
  m_professional     = "B15002_017", m_doctorate        = "B15002_018",
  f_bachelor_degree  = "B15002_032", f_masters_degree   = "B15002_033",
  f_professional     = "B15002_034", f_doctorate        = "B15002_035"
)

vars_health <- c(
  pop_under_19       = "B27010_002", pop_65_and_over    = "B27010_051",
  uninsured_under_34 = "B27010_033", uninsured_under_65 = "B27010_050"
)

vars_wealth <- c(
  median_hh_income   = "B19013_001", poverty_total      = "B17001_002",
  labor_force_total  = "B23025_003", unemployed         = "B23025_005"
)

# Year Structure Built Bins (Stable from 2015-2019)
bldg_bins_2015_2019 <- c(
  built_2014_later   = "B25034_002", built_2010_2013    = "B25034_003",
  built_2000_2009    = "B25034_004", built_1990_1999    = "B25034_005",
  built_1980_1989    = "B25034_006", built_1970_1979    = "B25034_007",
  built_1960_1969    = "B25034_008", built_1950_1959    = "B25034_009",
  built_1940_1949    = "B25034_010", built_1939_earlier = "B25034_011"
)

# Year Structure Built Bins (Stable from 2010-2014)
bldg_bins_2010_2014 <- c(
  built_2005_later   = "B25034_002", built_2000_2004    = "B25034_003",
  built_1990_1999    = "B25034_004", built_1980_1989    = "B25034_005",
  built_1970_1979    = "B25034_006", built_1960_1969    = "B25034_007",
  built_1950_1959    = "B25034_008", built_1940_1949    = "B25034_009",
  built_1939_earlier = "B25034_010"
)

# Variable groups for API calls
vars_2020_plus     <- c(vars_base, vars_health, vars_wealth, med_tenure = "B25039_001", med_building_age = "B25035_001")
vars_2015_2019     <- c(vars_base, vars_health, vars_wealth, med_tenure = "B25039_001", bldg_bins_2015_2019)
vars_2010_2014     <- c(vars_base, med_tenure = "B25039_001", bldg_bins_2010_2014)

# Bounds for the building age bins
bin_defs_2015_2019 <- tibble(
  bin_name = names(bldg_bins_2015_2019),
  lower = c(2014, 2010, 2000, 1990, 1980, 1970, 1960, 1950, 1940, 1939),
  upper = c(2019, 2013, 2009, 1999, 1989, 1979, 1969, 1959, 1949, 1939)
) |> mutate(width = (upper - lower) + 1)

bin_defs_2010_2014 <- tibble(
  bin_name = names(bldg_bins_2010_2014),
  lower = c(2005, 2000, 1990, 1980, 1970, 1960, 1950, 1940, 1939),
  upper = c(2013, 2004, 1999, 1989, 1979, 1969, 1959, 1949, 1939)
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

# 5. Pull and process ACS data for each year, applying stability tract logic
pull_acs_data <- function(year, stab) {
  message(paste("Pulling data for year:", year))
  
  if (year >= 2020) {
    # 2020+: Tract boundaries match. Pull directly.
    return(
      get_acs(geography = "tract", state = "MD", year = year,
              variables = vars_2020_plus, output = "wide", show_call = FALSE) |>
        mutate(year = year)
    )
  }
  
  # Pre-2020: Pull at the 2010 tract level, then map to 2020 geographies
  # Identify 2010 GEOIDs belonging to stable, minor, or merge-eligible 2020 tracts
  eligible_2020 <- stab |>
    filter(stability_class %in% c("Stable", "Minor boundary change", "Merge (many-to-one)"))
  
  eligible_rel <- rel |>
    inner_join(eligible_2020, by = "GEOID_TRACT_20")
  
  # Identify merges: 2020 tracts built from 2-3 source 2010 tracts
  # (drop merges with too many sources as unreliable)
  merge_source_counts <- eligible_rel |>
    filter(stability_class == "Merge (many-to-one)") |>
    count(GEOID_TRACT_20, name = "n_sources")
  
  eligible_2020 <- eligible_2020 |>
    left_join(merge_source_counts, by = "GEOID_TRACT_20") |>
    mutate(n_sources = replace_na(n_sources, 1)) |>
    filter(!(stability_class == "Merge (many-to-one)" & n_sources > 2))
  
  # Refresh eligible_rel after filtering
  eligible_rel <- rel |>
    inner_join(eligible_2020, by = "GEOID_TRACT_20")
  
  needed_2010_tracts <- unique(eligible_rel$GEOID_TRACT_10)
  
  # Pull ACS data at the 2010 tract level for the eligible set
  raw_tr <- get_acs(
    geography = "tract", state = "MD", year = year,
    # If the year is 2014 or later, use the 2014-2019 bin definitions
    # If the year is 2010 through 2013, use the 2010-2013 bin definitions
    if (year <= 2014) {
      variables = vars_2010_2014
    } else {
      variables = vars_2015_2019
    },
    output = "wide", show_call = FALSE
  ) |>
    filter(GEOID %in% needed_2010_tracts)
  
  # Stable & Minor: 2010 GEOID maps 1-to-1 onto a 2020 GEOID
  stable_minor_geoids <- eligible_rel |>
    filter(stability_class %in% c("Stable", "Minor boundary change")) |>
    distinct(GEOID_TRACT_10, GEOID_TRACT_20)
  
  stable_minor <- raw_tr |>
    inner_join(stable_minor_geoids, by = c("GEOID" = "GEOID_TRACT_10")) |>
    mutate(GEOID = GEOID_TRACT_20) |>
    select(-GEOID_TRACT_20)
  
  # Merges: sum counts across the constituent 2010 tracts
  merge_xwalk <- eligible_rel |>
    filter(stability_class == "Merge (many-to-one)") |>
    distinct(GEOID_TRACT_10, GEOID_TRACT_20)
  
  # Count variables (ending in E) are summable; med_tenure needs a weighted average
  merged <- raw_tr |>
    inner_join(merge_xwalk, by = c("GEOID" = "GEOID_TRACT_10")) |>
    mutate(
      med_tenureE = if_else(med_tenureE < 1900, NA_real_, med_tenureE),
      # Weight by total occupied housing units as a proxy for tenure denominator
      tenure_weight     = total_householdsE,
      weighted_tenure   = med_tenureE * tenure_weight,
      valid_weight_tenure = if_else(!is.na(med_tenureE), tenure_weight, 0)
    ) |>
    group_by(GEOID = GEOID_TRACT_20) |>
    summarise(
      # Sum all count variables
      across(
        c(ends_with("E"), -NAME, -med_tenureE),
        \(x) sum(x, na.rm = TRUE)
      ),
      # Weighted average for median tenure
      sum_wt_tenure     = sum(valid_weight_tenure, na.rm = TRUE),
      med_tenureE       = if_else(
        sum_wt_tenure > 0,
        sum(weighted_tenure, na.rm = TRUE) / sum_wt_tenure,
        NA_real_
      ),
      .groups = "drop"
    ) |>
    select(-sum_wt_tenure)
  
  # Combine stable/minor and merged
  combined <- bind_rows(stable_minor, merged) |>
    mutate(
      NAME = NA_character_,  # NAME is no longer meaningful post-merge
      year = year
    )
  
  # Apply the appropriate median calculation based on the year
  if (year <= 2014) {
    combined <- combined |>
      mutate(
        med_building_ageE = pmap_dbl(
          list(
            built_2005_laterE, built_2000_2004E, built_1990_1999E,
            built_1980_1989E,  built_1970_1979E, built_1960_1969E,
            built_1950_1959E,  built_1940_1949E, built_1939_earlierE
          ),
          ~ calc_interpolated_median(c(...), bin_defs_2010_2014)
        )
      )
  } else {
    combined <- combined |>
      mutate(
        med_building_ageE = pmap_dbl(
          list(
            built_2014_laterE, built_2010_2013E, built_2000_2009E,
            built_1990_1999E,  built_1980_1989E, built_1970_1979E,
            built_1960_1969E,  built_1950_1959E, built_1940_1949E,
            built_1939_earlierE
          ),
          ~ calc_interpolated_median(c(...), bin_defs_2015_2019)
        )
      )
  }

  # Clean up the raw bins
  combined <- combined |> 
    select(-starts_with("built_"))
  
  return(combined)
}
raw_acs_data <- map_dfr(years, ~pull_acs_data(.x, all_tracts_classified)) |>
  # Expand the dataset to include all combinations of 2020 tracts and years, 
  # automatically filling the non-eligible, dropped pre-2020 tracts with NA
  complete(GEOID = unique(all_tracts_classified$GEOID_TRACT_20), year = years)

# 6. Calculate derived variables (cost burden, overcrowding, etc.) from the raw ACS data
calc_cost_burden <- function(df) {
  df |>
    mutate(
      renter_denominator = renter_totalE - renter_not_compE,
      renter_mod_count = renter_30_34E + renter_35_39E + renter_40_49E,
      renter_sev_count = renter_50_plusE,
      pct_moderate_cost_burden_r = renter_mod_count / renter_denominator * 100,
      pct_severe_cost_burden_r = renter_sev_count / renter_denominator * 100,
      owner_denominator = (owner_m_totalE + owner_nm_totalE) - (owner_m_not_compE + owner_nm_not_compE),
      owner_mod_count = owner_m_30_34E + owner_m_35_39E + owner_m_40_49E + owner_nm_30_34E + owner_nm_35_39E + owner_nm_40_49E,
      owner_sev_count = owner_m_50_plusE + owner_nm_50_plusE,
      pct_moderate_cost_burden_o = owner_mod_count / owner_denominator * 100,
      pct_severe_cost_burden_o = owner_sev_count / owner_denominator * 100,
      total_households = renter_denominator + owner_denominator,
      pct_moderate_cost_burden = ((renter_mod_count + owner_mod_count) / total_households) * 100,
      pct_severe_cost_burden = ((renter_sev_count + owner_sev_count) / total_households) * 100,
      pct_homeowners = owner_denominator / total_households * 100
    ) |>
    select(GEOID, year, pct_moderate_cost_burden, pct_severe_cost_burden, pct_moderate_cost_burden_r, pct_severe_cost_burden_r, pct_moderate_cost_burden_o, pct_severe_cost_burden_o, pct_homeowners)
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

calc_health <- function(df) {
  df |>
    mutate(
      pop_under_65 = total_popE - pop_65_and_overE,
      pop_uninsured = uninsured_under_34E + uninsured_under_65E,
      pct_uninsured = (pop_uninsured / pop_under_65) * 100
    ) |>
    select(GEOID, year, pct_uninsured)
}

calc_wealth <- function(df) {
  df |>
    mutate(
      median_hh_income   = median_hh_incomeE,
      pct_poverty = (poverty_totalE / total_popE) * 100,
      pct_unemployed = (unemployedE / labor_force_totalE) * 100
    ) |>
    select(GEOID, year, median_hh_income, pct_poverty, pct_unemployed)
}

calc_demographics <- function(df) {
  df |>
    group_by(GEOID) |>
    arrange(year, .by_group = TRUE) |>
    mutate(
      minority_proportion = (total_popE - whiteE) / total_popE,
      bachelor_proportion = (m_bachelor_degreeE + m_masters_degreeE + m_professionalE + m_doctorateE +
        f_bachelor_degreeE + f_masters_degreeE + f_professionalE + f_doctorateE) / total_educatedE,
      pct_pt_change_minority = if_else(
        year == 2010, 
        NA_real_, 
        (minority_proportion - lag(minority_proportion)) * 100
      ),
      pct_pt_change_education = if_else(
        year == 2010,
        NA_real_,
        (bachelor_proportion - lag(bachelor_proportion)) * 100
      )
    ) |>
    select(GEOID, year, pct_pt_change_minority, pct_pt_change_education)
}

# 7. Compile and export the final ACS dataset with all derived variables
dfdenominators <- raw_acs_data |>
  mutate(
    true_vacant = vacant_countE - vacant_seasonalE,
    # Tracts with more than 33% seasonal vacancy are considered unreliable
    highly_seasonal = if_else(vacant_seasonalE / vacant_countE > 0.33, TRUE, FALSE),
    pct_grp_hsg = if_else(grp_hsg_totalE > 0, (grp_hsg_totalE / total_householdsE) * 100, 0)
  ) |>
  select(GEOID, year, total_pop = total_popE, total_households = total_householdsE, 
         total_owners_m = total_owners_mE, total_owners_nm = total_owners_nmE, 
         total_renters = total_rentersE, total_vacant = true_vacant, highly_seasonal = highly_seasonal,
         pct_grp_hsg = pct_grp_hsg)

dfcost_burden <- calc_cost_burden(raw_acs_data)
dftenure <- calc_tenure(raw_acs_data)
dfovercrowding <- calc_overcrowding(raw_acs_data)
dffacilities <- calc_facilities(raw_acs_data)
dfhealth <- calc_health(raw_acs_data)
dfwealth <- calc_wealth(raw_acs_data)
dfdemographics <- calc_demographics(raw_acs_data)
clean_acs_data <- list(
  dfdenominators,
  dfcost_burden,
  dftenure,
  dfovercrowding,
  dffacilities,
  dfhealth,
  dfwealth,
  dfdemographics
) |>
  reduce(left_join, by = c("GEOID", "year")) |>
  mutate(
    is_low_pop = total_households < 50 | is.na(total_households),
    is_maj_grp = pct_grp_hsg > 50,
    across(
      c(starts_with("pct_"), starts_with("med_")),
      ~ if_else(is_low_pop | is_maj_grp, NA_real_, .x)
    )
  ) |>
    select(-is_low_pop, -is_maj_grp)

output_file <- "../data/clean/acs_data.csv"
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_file)) {
  file.remove(output_file)
}
write_csv(clean_acs_data, output_file)