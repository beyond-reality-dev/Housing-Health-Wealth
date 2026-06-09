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

# 3. Save the merged dataset to a new CSV file
output_file <- "../data/clean/merged_panel_data.csv"
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_file)) {
  file.remove(output_file)
}
write_csv(merged_data, output_file)
