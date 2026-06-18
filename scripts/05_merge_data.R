# Load necessary libraries
library(tidyverse)

# 1. Pull in the cleaned ACS and NOI datasets
clean_acs_data <- read_csv("../data/clean/acs_data.csv")
clean_noi_data <- read_csv("../data/clean/noi_data.csv")
clean_vacancy_data <- read_csv("../data/clean/vacancy_data.csv")
clean_subsidized_data <- read_csv("../data/clean/subsidized_data.csv")


# 2. Merge the cleaned ACS and NOI datasets on GEOID and year
merged_data <- clean_acs_data |>
  left_join(clean_noi_data |> select(GEOID, year, noi_per_1000_owners), by = c("GEOID", "year")) |>
  left_join(clean_vacancy_data |> select(GEOID, year, vacancy_rate), by = c("GEOID", "year")) |>
  left_join(clean_subsidized_data |> select(GEOID, year, pct_subsidized_units), by = c("GEOID", "year"))

# 3. Import Just Communities designation data (if a GEOID matches, set new variable just_community = 1)
url <- "https://mdgeodata.md.gov/imap/rest/services/BusinessEconomy/MD_HousingDesignatedAreas/FeatureServer/9/query?where=1%3D1&outFields=*&outSR=4326&f=json"
just_communities <- jsonlite::fromJSON(url)
matching <- just_communities$features$attributes |> as_tibble() |> pull(GEOID) |> as.character()
merged_data <- merged_data |>
  mutate(just_community = ifelse(GEOID %in% matching, TRUE, FALSE))

# 4. Save the merged dataset to a new CSV file
output_file <- "../data/clean/merged_panel_data.csv"
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_file)) {
  file.remove(output_file)
}
write_csv(merged_data, output_file)
