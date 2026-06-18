# Load necessary libraries
library(tidyverse)
library(readxl)
library(sf)
library(tigris)

# 1. Load the raw NHPD subsidies dataset
nhpd_subsidies <- read_excel("../data/raw/subsidized/nhpd_subsidies.xlsx") |>
  rename(assisted_units = `Assisted Units`) |>
  mutate(
    start_year = suppressWarnings(as.integer(year(`Start Date`))),
    end_year = suppressWarnings(as.integer(year(`End Date`)))
  )

# 2. Fetch 2020 Maryland census tract shapefiles
md_tracts <- tracts(state = "MD", year = 2020, cb = TRUE, class = "sf") |>
  st_transform(4326) |>
  select(GEOID)

# 3. Generate the Annual Panel (2010-2024)
target_years <- 2010:2024

nhpd_annual_panel <- map_dfr(target_years, function(current_year) {

  # A. Temporal Filter
  active_this_year <- nhpd_subsidies |>
    filter(
      start_year <= current_year,
      (is.na(end_year) | end_year >= current_year)
    )
  
  # B. Deduplicate Subsidies (Maximum Overlap Assumption)
  property_level_assisted <- active_this_year |>
    group_by(`NHPD Property ID`, `Known Total Units`, Latitude, Longitude) |>
    summarize(
      max_subsidy_units = suppressWarnings(max(assisted_units, na.rm = TRUE)),
      .groups = "drop"
    ) |>
    mutate(
      estimated_assisted_units = case_when(
        is.infinite(max_subsidy_units) ~ 0,
        !is.na(`Known Total Units`) & max_subsidy_units > `Known Total Units` ~ as.numeric(`Known Total Units`),
        TRUE ~ as.numeric(max_subsidy_units)
      )
    )

  # C. Convert to spatial points
  property_spatial <- property_level_assisted |>
    filter(!is.na(Latitude) & !is.na(Longitude)) |>
    st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326)
  
  # D. Spatial join and Tract Summarization
  st_join(property_spatial, md_tracts, join = st_intersects) |>
    st_drop_geometry() |>
    filter(!is.na(GEOID) & str_starts(GEOID, "24")) |>
    group_by(GEOID) |>
    summarize(
      total_subsidized_units = sum(estimated_assisted_units, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(year = current_year)
    
}) 

# 4. Calculate subsidized unit shares from ACS data
acs_data <- read_csv("../data/clean/acs_data.csv", col_types = cols(GEOID = "c")) |>
  select(GEOID, year, total_households) |>
  filter(str_starts(GEOID, "24"))

nhpd_annual_panel <- nhpd_annual_panel |>
  left_join(acs_data, by = c("GEOID", "year")) |>
  mutate(
    pct_subsidized_units = if_else(
      total_households > 0,
      (total_subsidized_units / total_households) * 100,
      NA_real_
    )
  ) |>
  select(GEOID, year, total_subsidized_units, pct_subsidized_units)

# 5. Save the resulting panel dataset
output_file <- "../data/clean/subsidized_data.csv"
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_file)) {
  file.remove(output_file)
}
write_csv(nhpd_annual_panel, output_file)
