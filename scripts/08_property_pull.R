# Load necessary libraries
library(httr)
library(jsonlite)
library(dplyr)
library(lubridate)
library(sf)
library(tigris)
library(purrr)
library(readr)
 
# 1. Configuration
options(tigris_use_cache = TRUE)

socrata_token <- readLines("../socrata.key", warn = FALSE)

url <- "https://opendata.maryland.gov/resource/ed4q-f8tm.json"
years <- 2018:2024
min_sales_per_year <- 10 # Suppress tracts with fewer than this number of sales in a given year

cache_dir <- "../data/raw/mdp_cache"
dir.create(cache_dir, showWarnings = FALSE)

fields <- c(
  "account_id_mdp_field_acctid",
  "mdp_longitude_mdp_field_digxcord_converted_to_wgs84",
  "mdp_latitude_mdp_field_digycord_converted_to_wgs84",
  "sales_segment_1_transfer_date_yyyy_mm_dd_mdp_field_tradate_sdat_field_89",
  "sales_segment_1_consideration_mdp_field_considr1_sdat_field_90",
  "sales_segment_1_how_conveyed_ind_mdp_field_convey1_sdat_field_87",
  "sales_segment_2_transfer_date_yyyy_mm_dd_sdat_field_109",
  "sales_segment_2_consideration_sdat_field_110",
  "sales_segment_2_how_conveyed_ind_sdat_field_107",
  "sales_segment_3_transfer_date_yyyy_mm_dd_sdat_field_129",
  "sales_segment_3_consideration_sdat_field_130",
  "sales_segment_3_how_conveyed_ind_sdat_field_127"
)

# 2. Fetch MD SDAT property data for each year and cache it
fetch_mdp_paginated <- function(base_url, fields = NULL, page_size = 1000, clear_cache = FALSE,
                                 max_pages = NULL, cache_file = NULL) {

  if (clear_cache && !is.null(cache_file) && file.exists(cache_file)) {
    message("Clearing cached data at ", cache_file)
    file.remove(cache_file)
  }

  if (!is.null(cache_file) && file.exists(cache_file) && !clear_cache) {
    message("Loading cached data from ", cache_file)
    return(readRDS(cache_file))
  }

  offset <- 0
  results <- list()
  page <- 1

  repeat {
    query_params <- list(
      `$limit` = page_size,
      `$offset` = format(offset, scientific = FALSE),
      `$$app_token` = socrata_token
    )
    if (!is.null(fields)) {
      query_params[["$select"]] <- paste(fields, collapse = ",")
    }

    resp <- tryCatch(
      GET(base_url, query = query_params, timeout(60)),
      error = function(e) {
        message("Request error at offset ", offset, ": ", conditionMessage(e),
                " -- retrying after backoff")
        Sys.sleep(5)
        tryCatch(GET(base_url, query = query_params, timeout(60)),
                 error = function(e2) NULL)
      }
    )

    if (is.null(resp) || http_error(resp)) {
      status <- if (!is.null(resp)) status_code(resp) else NA
      body <- if (!is.null(resp)) content(resp, as = "text", encoding = "UTF-8") else "no response"
      message("Failed to fetch page at offset ", offset, " (status ", status, "): ", body)
      break  # stop instead of looping forever on a persistent error
    }

    chunk <- tryCatch(
      fromJSON(content(resp, as = "text", encoding = "UTF-8"), flatten = TRUE),
      error = function(e) NULL
    )

    if (is.null(chunk) || length(chunk) == 0 || nrow(chunk) == 0) break

    chunk <- as_tibble(chunk)
    results[[page]] <- chunk

    if (page %% 20 == 0) {
      saveRDS(bind_rows(results), file.path(cache_dir, "mdp_checkpoint.rds"))
      message(format(Sys.time(), "[%Y-%m-%d %H:%M:%S]"), 
        " Checkpoint saved at page ", page, " (offset ", offset, ")")
    }

    if (nrow(chunk) < page_size) break  # last page

    offset <- offset + page_size
    page <- page + 1
    Sys.sleep(0.3)

    if (!is.null(max_pages) && page > max_pages) break
  }

  out <- bind_rows(results)
  if (!is.null(cache_file)) saveRDS(out, cache_file)
  out
}

# 3. Pull data
mdp <- fetch_mdp_paginated(
  url,
  fields = fields,
  page_size = 10000,
  clear_cache = FALSE,
  cache_file = file.path(cache_dir, "mdp_raw.rds")
)

message("Pulled ", nrow(mdp), " parcel records")
 
# Shorten column names for workability
names(mdp) <- c(
  "account_id", "longitude", "latitude",
  "sale1_date", "sale1_price", "sale1_conveyed",
  "sale2_date", "sale2_price", "sale2_conveyed",
  "sale3_date", "sale3_price", "sale3_conveyed"
)

# 4. Reshape records to long format for sales segments
parse_mdp_date <- function(x) {
  # Source format is YYYY.MM.DD per the field documentation
  suppressWarnings(as_date(gsub("\\.", "-", as.character(x))))
}
 
sales_long <- bind_rows(
  mdp |> transmute(account_id, longitude, latitude,
                     sale_date = parse_mdp_date(sale1_date),
                     sale_price = as.numeric(sale1_price),
                     how_conveyed = sale1_conveyed),
  mdp |> transmute(account_id, longitude, latitude,
                     sale_date = parse_mdp_date(sale2_date),
                     sale_price = as.numeric(sale2_price),
                     how_conveyed = sale2_conveyed),
  mdp |> transmute(account_id, longitude, latitude,
                     sale_date = parse_mdp_date(sale3_date),
                     sale_price = as.numeric(sale3_price),
                     how_conveyed = sale3_conveyed)
)

# 5. Filter out invalid sales and keep only those in the target years
sales_filtered <- sales_long |>
  filter(!is.na(sale_date), !is.na(sale_price), sale_price > 0) |>
  mutate(
    sale_year = year(sale_date),
    how_conveyed_clean = trimws(tolower(how_conveyed))
  ) |>
  filter(
    sale_year %in% years,
    !is.na(how_conveyed),
    how_conveyed_clean != "no data",
    !grepl("non-arms-length|non arms length|non-arm's-length", how_conveyed_clean)
  )
 
geocode_pct <- mean(!is.na(sales_filtered$latitude) & !is.na(sales_filtered$longitude))
message(sprintf("Geocoding coverage: %.1f%% of filtered sales have lat/long", geocode_pct * 100))
 
excluded_n <- nrow(sales_long |> filter(!is.na(sale_date), !is.na(sale_price), sale_price > 0)) -
              nrow(sales_filtered)
message(excluded_n, " sales excluded as 'No Data' or non-arm's-length conveyance")
message("Remaining ", nrow(sales_filtered), " sales after filtering for valid sales and target years")

# 6. Geocode sales to census tracts using tigris
sales_sf <- sales_filtered |>
  filter(!is.na(longitude), !is.na(latitude)) |>
  st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
 
md_tracts <- tracts(state = "MD", cb = TRUE, year = 2022) |>
  st_transform(4326)
 
sales_tract <- st_join(sales_sf, md_tracts["GEOID"], join = st_within) |>
  st_drop_geometry()
 
unmatched <- sum(is.na(sales_tract$GEOID))
if (unmatched > 0) {
  message(unmatched, " sales (", round(100 * unmatched / nrow(sales_tract), 1),
          "%) did not match a tract -- check for bad coordinates")
}
 
sales_tract <- sales_tract |> filter(!is.na(GEOID))

# 7. Calculate median sale price and appreciation per tract per year and filter for tracts with sufficient sales
median_price_by_tract_year <- sales_tract |>
  group_by(GEOID, sale_year) |>
  summarise(median_price = median(sale_price, na.rm = TRUE),
            n_sales = n(),
            .groups = "drop") |>
  mutate(reliable = n_sales >= min_sales_per_year) |>
  arrange(GEOID, sale_year) |>
  group_by(GEOID) |>
  mutate(appreciation = (median_price / lag(median_price)) - 1) |>
  ungroup() |>
  select(GEOID, year = sale_year, median_sale_price = median_price, appreciation_rate = appreciation)

# 8. Save the property data to a CSV file
output_file <- "../data/clean/property_data.csv"
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
if (file.exists(output_file)) {
  file.remove(output_file)
}
write_csv(median_price_by_tract_year, output_file)
