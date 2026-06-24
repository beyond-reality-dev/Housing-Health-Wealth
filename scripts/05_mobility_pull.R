# Load necessary libraries
library(sf)
library(dplyr)
library(tidycensus)
install.packages("purrr", repos = "https://cloud.r-project.org")
library(purrr)
library(readr)

# 1. Load the 2024-2025 school attendance zones
zones_url <- "https://mdpgis.mdp.state.md.us/arcgis/rest/services/Society/ENOUGH_Act_2025/MapServer/1/query?where=1=1&outFields=*&f=geojson"
school_zones <- st_read(zones_url) |>
  st_transform(crs = 6487) |>
  st_make_valid()
school_zones <- school_zones |>
  mutate(
    lss_str = sprintf("%02d", as.integer(substr(SCHOOL_DISTRICT_NAME, 1, 2))), 
    sch_str = sprintf("%04d", as.integer(IAC_ID_2)),
    school_id = paste0(lss_str, sch_str)
  ) |>
  select(school_id, geometry)

# 2. Fetch 2020 Maryland block group shapefiles
md_bgs_geom <- get_acs(
  geography = "block group",
  variables = "B01003_001", 
  state = "MD",
  year = 2020, 
  geometry = TRUE
) |>
  select(GEOID) |>
  st_transform(crs = 6487) |>
  st_make_valid() |>
  mutate(
    original_area = as.numeric(st_area(geometry)),
    tract_id = substr(GEOID, 1, 11)
  )

# 3. Perform spatial intersection between block groups and school zones
spatial_crosswalk <- st_intersection(md_bgs_geom, school_zones) |>
  mutate(
    intersected_area = as.numeric(st_area(geometry)),
    area_ratio = intersected_area / original_area
  ) |>
  st_drop_geometry() |>
  select(GEOID, tract_id, school_id, area_ratio)

# 4. Load the cleaned enrollment data for 2020-2024
years <- 2020:2024

mobility_data_list <- lapply(years, function(current_year) {
  message("Processing mobility data for year: ", current_year)
  mobility_file <- paste0("../data/raw/msde/Student_Mobility_", current_year, ".csv")
  mobility_data <- read_csv(mobility_file, show_col_types = FALSE) |>
    filter(`School Type` == "Elementary")
  if("LSS Number" %in% names(mobility_data)) {
    mobility_data <- mobility_data |> rename(county_code = `LSS Number`)
  } else if ("LEA Number" %in% names(mobility_data)) {
    mobility_data <- mobility_data |> rename(county_code = `LEA Number`)
  }
  mobility_data <- mobility_data |>
    mutate(
      lss_csv = sprintf("%02d", as.integer(county_code)),
      sch_csv = sprintf("%04d", as.integer(`School Number`)),
      school_id = paste0(lss_csv, sch_csv),
      withdrawals_rate = as.character(`Withdrawals Rate`),
      numeric_rate = case_when(
        withdrawals_rate == "<= 5.0" ~ 5,  # Conservative assumption for suppressed values
        withdrawals_rate == "*" ~ 5,       # Conservative assumption for suppressed values
        withdrawals_rate == "> 95.0" ~ 95, # Conservative assumption for extreme values
        TRUE ~ suppressWarnings(as.numeric(withdrawals_rate)) 
      ),
      year = current_year
    ) |>
    filter(!is.na(school_id)) |>
    select(school_id, year, withdrawals_rate = numeric_rate)
  return(mobility_data)
})

all_mobility_data <- bind_rows(mobility_data_list)

# 5. Fetch Population, Join, and Calculate Final Tract Index
final_panel_data <- map_dfr(years, function(current_year) {

  message("Fetching population and calculating for year: ", current_year)
  
  # A. Fetch ACS Block Group population for this specific year
  yearly_pop <- get_acs(
    geography = "block group",
    variables = "B01003_001",
    state = "MD",
    year = current_year,
    geometry = FALSE
  ) |>
    rename(bg_pop = estimate) |>
    select(GEOID, bg_pop) |>
    mutate(tract_id = substr(GEOID, 1, 11))
  
  # B. Calculate total population for each tract this year
  tract_totals <- yearly_pop |>
    group_by(tract_id) |>
    summarize(tract_pop = sum(bg_pop, na.rm = TRUE), .groups = "drop")
  
  # C. Filter our master mobility data for just this year
  mobility_yr <- all_mobility_data |> 
    filter(year == current_year)
  
  # D. Join everything together and calculate the Churn Index
  yearly_churn <- spatial_crosswalk |>
    left_join(yearly_pop, by = c("GEOID", "tract_id")) |>
    left_join(tract_totals, by = "tract_id") |>
    left_join(mobility_yr, by = "school_id") |>
    filter(tract_pop > 0, !is.na(withdrawals_rate)) |>
    # 1. Slice the block group population using the area_ratio
    mutate(apportioned_pop = bg_pop * area_ratio) |>
    # 2. Add up all the population pieces for each school within the tract
    group_by(tract_id, school_id, tract_pop, withdrawals_rate) |>
    summarize(pop_in_zone = sum(apportioned_pop, na.rm = TRUE), .groups = "drop") |>
    # 3. Apply the final weighting formula
    group_by(tract_id) |>
    summarize(
      churn_index = sum((pop_in_zone / tract_pop) * withdrawals_rate, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(year = current_year) |>
    select(GEOID = tract_id, year, withdrawal_rate = churn_index)
  return(yearly_churn)
})

# 6. Calculate change in churn index for each tract over time
final_panel_data <- final_panel_data |>
  group_by(GEOID) |>
  arrange(year) |>
  mutate(
    prev_year_churn = lag(withdrawal_rate),
    change_in_churn = withdrawal_rate - prev_year_churn
  ) |>
  ungroup() |>
  select(GEOID, year, withdrawal_rate, change_in_churn)

# 7. Save the enrollment churn panel to a CSV file
output_file <- "../data/clean/enrollment_churn.csv"
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_file)) {
  file.remove(output_file)
}
write_csv(final_panel_data, output_file)
