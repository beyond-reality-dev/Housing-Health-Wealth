# Load necessary libraries
library(tidyverse)

# 1. Read RUCA lookup for Maryland tracts
ruca_codes <- read_csv("../data/raw/vacancy/ruca_codes.csv", show_col_types = FALSE) |>
  mutate(GEOID = as.character(TractFIPS23)) |>
  select(GEOID, PrimaryRUCA) |>
  filter(str_starts(GEOID, "24"))

# 2. Read USPS vacancy files for 2020-2023
vacancy_files <- list.files("../data/raw/vacancy/", pattern = "\\.dbf$", full.names = TRUE)
vacancy_data <- map_dfr(vacancy_files, function(file) {
  if (requireNamespace("sf", quietly = TRUE)) {
    df <- tryCatch(
      sf::st_read(file, quiet = TRUE) |> sf::st_drop_geometry(),
      error = function(e) {
        if (requireNamespace("foreign", quietly = TRUE)) {
          foreign::read.dbf(file, as.is = TRUE)
        } else {
          stop(e)
        }
      }
    )
  } else if (requireNamespace("foreign", quietly = TRUE)) {
    df <- foreign::read.dbf(file, as.is = TRUE)
  } else {
    stop("Neither sf nor foreign is available to read DBF files.")
  }

  df |>
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

# 3. Crosswalk years 2020-2023 from 2010 GEOIDs to 2020 GEOIDs
crosswalk <- readxl::read_excel("../data/raw/vacancy/tract_crosswalk.xlsx") |>
  mutate(
    GEOID_2010 = as.character(GEOID_2010),
    GEOID_2020 = as.character(GEOID_2020),
    RES_RATIO = as.numeric(RES_RATIO)
  ) |>
  filter(
    str_starts(GEOID_2010, "24"),
    str_starts(GEOID_2020, "24")
  )

vacancy_data <- vacancy_data |>
  left_join(crosswalk, by = c("GEOID" = "GEOID_2010"), relationship = "many-to-many") |>
  mutate(
    weight = if_else(year <= 2023, coalesce(RES_RATIO, 1), 1),
    GEOID = if_else(year <= 2023, coalesce(GEOID_2020, GEOID), GEOID),
    tot_addresses = tot_addresses * weight,
    tot_vac = tot_vac * weight,
    tot_nostat = tot_nostat * weight
  ) |>
  select(GEOID, year, tot_addresses, tot_vac, tot_nostat) |>
  group_by(GEOID, year) |>
  summarize(
    across(c(tot_addresses, tot_vac, tot_nostat), \(x) sum(x, na.rm = TRUE)),
    .groups = "drop"
  )

# 4. Calculate USPS vacancy rates and classify tracts by RUCA codes
# Urban tracts (RUCA 1) have very high correlation with ACS vacancy (0.767)
# Non-urban tracts have unreliable vacancy data, so they are set to NA
vacancy_data <- vacancy_data |>
  left_join(ruca_codes, by = "GEOID") |>
  mutate(
    vacancy_rate = case_when(
      PrimaryRUCA == 1 ~ tot_vac / tot_addresses,
      PrimaryRUCA != 1 ~ NA,
      TRUE ~ NA_real_
    )
  )

# 5. Save cleaned vacancy panel
output_file <- "../data/clean/vacancy_data.csv"
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_file)) {
  file.remove(output_file)
}
write_csv(vacancy_data, output_file)