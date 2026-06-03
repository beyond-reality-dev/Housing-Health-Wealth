# Load necessary libraries
library(tidyverse)

# 1. Pull in the cleaned ACS and NOI datasets
clean_acs_data <- read_csv("../data/clean/acs_data.csv")
clean_noi_data <- read_csv("../data/clean/noi_data.csv")

# 2. Merge the cleaned ACS and NOI datasets on GEOID and year
merged_data <- clean_acs_data %>%
  left_join(clean_noi_data, by = c("GEOID", "year"))

# 3. Calculate the foreclosure rate as NOI per 1,000 owner-occupied households
merged_data <- merged_data %>%
  mutate(
    foreclosure_rate = (total_noi / total_owners) * 1000
  )

# 4. Save the merged dataset to a new CSV file
output_file <- "../data/clean/merged_panel_data.csv"
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_file)) {
  file.remove(output_file)
}
write_csv(merged_data, output_file)
