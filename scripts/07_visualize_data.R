# Load necessary libraries
library(tidyverse)
library(sf)
library(tigris)
library(leaflet)
library(htmltools)

# 1. Read the HSI data with GEOIDs and years
hsi_data <- read_csv("../data/clean/hsi_data.csv") |>
  mutate(GEOID = as.character(GEOID))

# 2. Filter for your target map year (e.g., 2024) and join the geometry
md_tracts <- tracts(state = "MD", year = 2020, cb = TRUE, class = "sf") |> select(GEOID)
hsi_multi_year <- md_tracts |>
  left_join(
    hsi_data |> mutate(GEOID = as.character(GEOID)), 
    by = "GEOID"
  )

# 2. Define a unified color palette across all years (0 to 100)
pal <- colorNumeric(
  palette = "magma", 
  domain = c(0, 100), 
  na.color = "grey80"
)

# 3. Initialize the base map
timeline_map <- leaflet() |>
  addProviderTiles(providers$CartoDB.Positron)

# 4. Loop through each year and add it as a separate layer group
target_years <- 2020:2024

for (current_year in target_years) {
  # Filter data for just this loop's year
  year_data <- hsi_multi_year |> filter(year == current_year)
  
  timeline_map <- timeline_map |>
    addPolygons(
      data = year_data,
      fillColor = ~pal(hsi_score),
      weight = 0.3,
      color = "white",
      fillOpacity = 0.85,
      # Give this layer a unique group name (e.g., "Year 2022")
      group = as.character(current_year),
      popup = ~paste0(
        "<strong>Tract: </strong>", GEOID, "<br>",
        "<strong>Year: </strong>", current_year, "<br>",
        "<strong>HSI Score: </strong>", round(hsi_score, 1), "<br>",
        "<strong>Z-Score: </strong>", round(hsi_zscore, 2)
      )
    )
}

# 5. Add the interactive control panel
timeline_map <- timeline_map |>
  addLayersControl(
    baseGroups = as.character(target_years),
    options = layersControlOptions(collapsed = FALSE),
    position = "topright"
  ) |>
  addLegend(
    pal = pal, 
    values = c(0, 100), 
    title = "Housing Stability Index",
    position = "bottomright"
  )

# 6. Save html output
output_html <- "../output/hsi_timeline_map.html"
dir.create(dirname(output_html), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_html)) {
  file.remove(output_html)
}
htmlwidgets::saveWidget(timeline_map, file = output_html, selfcontained = TRUE)
