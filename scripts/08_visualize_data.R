# Load necessary libraries
library(tidyverse)
library(tidycensus)
library(dplyr)
library(sf)
library(tigris)
library(leaflet)
library(htmltools)

# 1. Read the HSI data with GEOIDs and years
hsi_data <- read_csv("../data/clean/hsi_data.csv") |>
  mutate(GEOID = as.character(GEOID))

# 2. Pull county names for display purposes
data("fips_codes")
fips_lookup <- fips_codes |>
  mutate(county_fips = paste0(state_code, county_code)) %>%
  select(county_fips, county)
hsi_data <- hsi_data |>
  mutate(county_fips = substr(GEOID, 1, 5)) |>
  left_join(fips_lookup, by = "county_fips") |>
  mutate(county = ifelse(county == "Baltimore city", "Baltimore City", county))

# 3. Filter for your target map year (e.g., 2024) and join the geometry
md_tracts <- tracts(state = "MD", year = 2020, cb = TRUE, class = "sf") |> select(GEOID)
mapped_data <- md_tracts |>
  left_join(
    hsi_data |> mutate(GEOID = as.character(GEOID)), 
    by = "GEOID"
  )

# 4. Define unique color palettes for each index
pal_hsi <- colorNumeric(palette = "inferno", domain = c(0, 100), na.color = "grey")

# 5. Initialize separate base maps
hsi_map <- leaflet() |> addProviderTiles(providers$CartoDB.Positron)

# 6. Loop through each year and add polygons to both maps
target_years <- 2020:2024
for (current_year in target_years) {
  year_data <- mapped_data |> filter(year == current_year)
  
  # Populate HSI Map
  hsi_map <- hsi_map |>
    addPolygons(
      data = year_data,
      fillColor = ~pal_hsi(hsi_score),
      weight = 0.3,
      color = "white",
      fillOpacity = 0.85,
      group = as.character(current_year),
      popup = ~paste0(
        "<strong>Tract: </strong>", GEOID, "<br>",
        "<strong>County: </strong>", county, "<br>",
        "<strong>HSI Score: </strong>", round(hsi_score, 1), "<br>",
        "<strong>HSI Z-Score: </strong>", round(hsi_zscore, 2), "<br>",
        "<strong>HSI Percentile: </strong>", round(hsi_percentile, 1), "<br>",
        "<strong>Displacement Risk: </strong>", displacement_category, "<br>",
        "<em>Note: Displacement risk is based on changes in minority population, educational attainment, and school withdrawal rates and should be evaluated contextually.</em>"
      )
    )
}

# 7. Add controls and legends to their respective maps
hsi_map <- hsi_map |>
  addLayersControl(baseGroups = as.character(target_years), options = layersControlOptions(collapsed = FALSE), position = "topright") |>
  addLegend(pal = pal_hsi, values = c(0, 100), title = "Housing Stability Index", position = "bottomright")

# 8. Construct a Bootstrap layout with custom JS to fix tab-switching rendering bugs
dashboard_html <- tags$html(
  tags$head(
    tags$link(rel = "stylesheet", href = "https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css"),
    tags$script(src = "https://code.jquery.com/jquery-3.5.1.slim.min.js"),
    tags$script(src = "https://cdn.jsdelivr.net/npm/bootstrap@4.5.2/dist/js/bootstrap.bundle.min.js"),
    tags$style(HTML("
      body, html { height: 100%; margin: 0; padding: 0; }
      .tab-content, .tab-pane { height: calc(100vh - 50px); width: 100%; }
      .leaflet-container { height: 100% !important; width: 100% !important; }
    ")),
    tags$script(HTML("
      $(document).ready(function(){
        $('a[data-toggle=\"tab\"]').on('shown.bs.tab', function (e) {
          window.dispatchEvent(new Event('resize'));
        });
      });
    "))
  ),
  tags$body(
    tags$ul(class = "nav nav-tabs", id = "indexTabs", role = "tablist", style = "height: 50px; background-color: #f8f9fa;",
      tags$li(class = "nav-item",
        tags$a(class = "nav-link active", id = "hsi-tab", `data-toggle` = "tab", href = "#hsi-panel", role = "tab", "Housing Stability Index (HSI)")
      )
    ),
    tags$div(class = "tab-content", id = "indexTabsContent",
      tags$div(class = "tab-pane fade show active", id = "hsi-panel", role = "tabpanel", hsi_map)
    )
  )
)

# 9. Save output
output_html <- "../output/housing_dashboard.html"
dir.create(dirname(output_html), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_html)) {
  file.remove(output_html)
}

htmltools::save_html(dashboard_html, file = output_html)