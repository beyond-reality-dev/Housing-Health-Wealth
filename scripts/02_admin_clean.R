# Load necessary libraries
library(tidyverse)

# 1. Define the Socrata API endpoint for the NOI data
noi_url <- "https://opendata.maryland.gov/resource/nme2-wik5.csv?$limit=1500"

# 2. Pull the dataset
raw_noi_data <- read_csv(noi_url)

# 3. Clean and reshape from wide to long (panel) format
clean_noi_data <- raw_noi_data %>%
  pivot_longer(
    cols = -geoid20, 
    names_to = "year",
    values_to = "total_noi"
  ) %>%
  mutate(
    # Extract just the 4-digit year from the Socrata column names (e.g., "_2022")
    year = as.numeric(str_extract(year, "\\d{4}")),
    
    # Rename geoid20 to standard GEOID and ensure it is a character string
    GEOID = as.character(geoid20),
    
    # Ensure the count is treated as a number
    total_noi = as.numeric(total_noi)
  ) %>%
  # Keep only the standardized panel columns
  select(GEOID, year, total_noi)

output_file <- "../data/clean/noi_data.csv"

# Make sure the output folder exists when the script is run from scripts/
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)

# Delete existing file if it exists to avoid appending to old data
if (file.exists(output_file)) {
  file.remove(output_file)
}

# Save the cleaned NOI data to a CSV file
write_csv(clean_noi_data, output_file)

# See how many NAs exist in each year
clean_noi_data %>%
  group_by(year) %>%
  summarize(
    total_suppressed = sum(is.na(total_noi)),
    # You can also count how many valid rows you have for comparison
    valid_rows = sum(!is.na(total_noi)) 
  )