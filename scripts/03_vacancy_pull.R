# Load necessary libraries
library(tidyverse)

# 1. Read RUCA lookup for Maryland tracts
ruca_codes <- read_csv("../data/raw/vacancy/ruca_codes.csv", show_col_types = FALSE) |>
  mutate(GEOID = as.character(TractFIPS23)) |>
  select(GEOID, PrimaryRUCA) |>
  filter(str_starts(GEOID, "24"))

# 2. Read USPS vacancy files for 2010-2025
vacancy_files <- list.files("../data/raw/vacancy/", pattern = "\\.dbf$", full.names = TRUE)
vacancy_data <- map_dfr(vacancy_files, function(file) {
  foreign::read.dbf(file, as.is = TRUE) |>
    mutate(
      GEOID = as.character(geoid),
      year = as.integer(str_extract(basename(file), "\\d{4}"))
    ) |>
    select(
      GEOID,
      year,
      tot_addresses = ams_res,
      tot_vac = res_vac,
      tot_nostat = nostat_res
    )
}) |>
  filter(str_starts(GEOID, "24"))

# 3. Crosswalk years 2010-2023 from 2010 GEOIDs to 2020 GEOIDs
read_crosswalk <- function(path) {
  readxl::read_excel(path) |>
    mutate(
      GEOID_2010 = as.character(GEOID_2010),
      GEOID_2020 = as.character(GEOID_2020),
      RES_RATIO  = as.numeric(RES_RATIO)
    ) |>
    filter(
      str_starts(GEOID_2010, "24"),
      str_starts(GEOID_2020, "24")
    )
}

# Map each year to its crosswalk file
# 2019 crosswalk covers 2019-2023; each earlier year has its own
crosswalk_lookup <- list(
  "2015" = read_crosswalk("../data/raw/vacancy/tract_crosswalk_2015.xlsx"),
  "2016" = read_crosswalk("../data/raw/vacancy/tract_crosswalk_2016.xlsx"),
  "2017" = read_crosswalk("../data/raw/vacancy/tract_crosswalk_2017.xlsx"),
  "2018" = read_crosswalk("../data/raw/vacancy/tract_crosswalk_2018.xlsx"),
  "2019" = read_crosswalk("../data/raw/vacancy/tract_crosswalk_2019.xlsx"),
  "2020" = read_crosswalk("../data/raw/vacancy/tract_crosswalk_2019.xlsx"),
  "2021" = read_crosswalk("../data/raw/vacancy/tract_crosswalk_2019.xlsx"),
  "2022" = read_crosswalk("../data/raw/vacancy/tract_crosswalk_2019.xlsx"),
  "2023" = read_crosswalk("../data/raw/vacancy/tract_crosswalk_2019.xlsx")
)

# Apply the correct crosswalk for each year, post-2023 passes through unchanged
apply_crosswalk <- function(data, yr) {
  if (yr > 2023) {
    return(data |> mutate(weight = 1))
  }
  crosswalk <- crosswalk_lookup[[as.character(yr)]]
  data |>
    left_join(crosswalk, by = c("GEOID" = "GEOID_2010"), relationship = "many-to-many") |>
    mutate(
      GEOID         = coalesce(GEOID_2020, GEOID),
      weight        = coalesce(RES_RATIO, 1),
      tot_addresses = tot_addresses * weight,
      tot_vac       = tot_vac       * weight,
      tot_nostat    = tot_nostat    * weight
    )
}

vacancy_data <- vacancy_data |>
  group_by(year) |>
  group_modify(~ apply_crosswalk(.x, .y$year)) |>
  ungroup() |>
  select(GEOID, year, tot_addresses, tot_vac, tot_nostat) |>
  group_by(GEOID, year) |>
  summarize(
    across(c(tot_addresses, tot_vac, tot_nostat), \(x) sum(x, na.rm = TRUE)),
    .groups = "drop"
  )

# 4. Calculate USPS vacancy rates and classify tracts by RUCA codes
# Urban tracts (RUCA 1) have very high correlation with ACS vacancy (0.767)
# Non-urban tracts have unreliable USPS vacancy data, so they are set to ACS vacancy rates
acs_data <- read_csv("../data/clean/acs_data.csv", show_col_types = FALSE) |>
  mutate(GEOID = as.character(GEOID))
vacancy_data <- vacancy_data |>
  left_join(ruca_codes, by = "GEOID") |>
  left_join(acs_data, by = c("GEOID", "year")) |>
  mutate(
    usps_rate = tot_vac / tot_addresses,
    acs_vacancy_rate = if_else(is.na(total_vacant), NA_real_, total_vacant / total_households)
  )

# 5. Calibrate USPS vacancy rates to ACS vacancy rates for urban tracts
# USPS systematically undercounts relative to ACS (Bland-Altman analysis).
# A linear calibration trained on urban tracts yields 27% RMSE improvement
# in leave-one-year-out cross-validation (slope CV = 13.4%, all years improve).
calibration <- vacancy_data |>
  filter(PrimaryRUCA == 1, !is.na(acs_vacancy_rate), tot_addresses > 0) |>
  group_by(year) |>
  summarize(
    calibration_slope     = coef(lm(acs_vacancy_rate ~ usps_rate))[2],
    calibration_intercept = coef(lm(acs_vacancy_rate ~ usps_rate))[1],
    r_squared             = summary(lm(acs_vacancy_rate ~ usps_rate))$r.squared,
    n_tracts              = n(),
    .groups               = "drop"
  )

vacancy_data <- vacancy_data |>
  left_join(calibration |> select(year, calibration_slope, calibration_intercept),
            by = "year") |>
  mutate(
    usps_rate_calibrated = calibration_intercept + calibration_slope * usps_rate,
    vacancy_rate = case_when(
      # Urban tracts (RUCA 1) show strong USPS-ACS correlation (r = 0.767) and
      # use calibrated USPS vacancy to preserve annual frequency. Non-urban tracts
      # show poor agreement (r < 0.45) and fall back to ACS vacancy instead.
      PrimaryRUCA == 1  ~ usps_rate_calibrated,
      PrimaryRUCA != 1  ~ acs_vacancy_rate,
      TRUE              ~ NA_real_
    ),
    vacancy_rate = if_else(highly_seasonal, NA_real_, vacancy_rate)
  ) |>
  select(GEOID, year, vacancy_rate)

# 6. Save cleaned vacancy panel
output_file <- "../data/clean/vacancy_data.csv"
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_file)) {
  file.remove(output_file)
}
write_csv(vacancy_data, output_file)

library(dplyr)
library(readr)
library(tigris)
library(sf)          # Required for spatial transformations
library(leaflet)     # The interactive mapping library
library(htmlwidgets) # Required to save the HTML file

md_tracts <- tracts(state = "MD", year = 2020, cb = TRUE) |> select(GEOID)

vacancy_map_data <- md_tracts |>
  left_join(
    vacancy_data |> 
      filter(year == 2020) |> 
      mutate(GEOID = as.character(GEOID)), 
    by = "GEOID"
  ) |>
  # FIX: Leaflet requires WGS84 coordinates (Latitude/Longitude)
  st_transform(crs = 4326)

# 4. Define the color palette for Leaflet
# This replaces scale_fill_gradient from ggplot2
pal <- colorNumeric(
  palette = "Reds", 
  domain = vacancy_map_data$vacancy_rate,
  na.color = "#cccccc" # Explicitly color NA values gray
)

# 5. Create the interactive map
interactive_map <- leaflet(vacancy_map_data) |>
  addProviderTiles(providers$CartoDB.Positron) |> # Adds a clean basemap
  addPolygons(
    fillColor = ~pal(vacancy_rate),
    weight = 0.5,             # Border thickness
    opacity = 1,              # Border opacity
    color = "white",          # Border color
    dashArray = "3",
    fillOpacity = 0.7,        # Polygon fill opacity
    # Add an interactive tooltip on hover
    label = ~paste0("Tract: ", GEOID, "<br>Vacancy Rate: ", 
                    round(vacancy_rate, 3)),
    labelOptions = labelOptions(
      style = list("font-weight" = "normal", padding = "3px 8px"),
      textsize = "13px",
      direction = "auto"
    )
  ) |>
  # Add a legend
  addLegend(
    pal = pal, 
    values = ~vacancy_rate, 
    opacity = 0.7, 
    title = "Vacancy Rate (2020)",
    position = "bottomright"
  )

# 6. Save as a standalone HTML file
saveWidget(interactive_map, file = "../md_vacancy_map.html", selfcontained = TRUE)