# Load necessary libraries
library(tidyverse)
library(sf)

# 1. Read raw health data from the MarylandEnviroScreen API
# Format the following as a JSON Request: https://mdgeodata.md.gov/imap/rest/services/Environment/MD_EnviroScreen/MapServer/0/
url <- "https://mdgeodata.md.gov/imap/rest/services/Environment/MD_EnviroScreen/MapServer/0/query?where=1%3D1&outFields=GEOID20,P_BIRTH,P_Asthma,P_MYOCARDIAL&returnGeometry=false&f=json"
health_data <- jsonlite::fromJSON(url)

# 2. Convert the health data to a tibble and select relevant columns
health_data <- health_data$features$attributes |>
  as_tibble() |>
  mutate(
    GEOID = as.character(GEOID20),
    year = 2024,
    percentile_low_birth_weight = as.numeric(P_BIRTH),
    percentile_asthma = as.numeric(P_Asthma),
    percentile_myocardial_infarction = as.numeric(P_MYOCARDIAL)
  ) |>
  select(GEOID, year, percentile_low_birth_weight, percentile_asthma, percentile_myocardial_infarction)

# 3. Save the health data to a CSV file
output_file <- "../data/clean/health_data.csv"
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_file)) {
  file.remove(output_file)
}
write_csv(health_data, output_file)
