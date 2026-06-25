# Housing, Health, and Wealth Analyzer <!-- omit in toc -->

This repository contains code and documentation for the Housing, Health, and Wealth Analyzer project. The project aims to analyze the relationships between Housing Stability, Health Outcomes, and Wealth Accumulation across Maryland census tracts.

## Table of Contents <!-- omit in toc -->
- [Project Overview](#project-overview)
- [Project Structure](#project-structure)
- [Data Sources](#data-sources)
  - [Data Source Summary Table](#data-source-summary-table)
  - [ACS Data](#acs-data)
  - [NOI Data](#noi-data)
  - [Vacancy Data](#vacancy-data)
  - [Subsidized Housing Data](#subsidized-housing-data)
  - [School Enrollment Data](#school-enrollment-data)
  - [Health Data](#health-data)
- [Usage](#usage)
  - [Requirements](#requirements)
  - [Running the Scripts](#running-the-scripts)
  - [Outputs](#outputs)
    - [Known Harmless Warnings](#known-harmless-warnings)
- [Methodological Notes](#methodological-notes)
  - [American Community Survey (ACS) Data](#american-community-survey-acs-data)
  - [Notice of Intent to Foreclose (NOI) Data](#notice-of-intent-to-foreclose-noi-data)
  - [Vacancy Data](#vacancy-data-1)
  - [Subsidized Housing Data](#subsidized-housing-data-1)
  - [School Mobility Data](#school-mobility-data)
  - [Maryland Health Data](#maryland-health-data)
  - [Index Construction](#index-construction)
- [Contact](#contact)
- [Bibliography](#bibliography)

## Project Overview
The Housing, Health, and Wealth Analyzer project is designed to operationalize the Maryland Department of Housing and Community Development's (DHCD) Housing, Health, and Wealth (HHW) framework. The framework aims to forward DHCD's mission of providing every Marylander “the opportunity to live and prosper in affordable, lovable and just communities” across three domains: Housing Stability, Health Outcomes, and Wealth Accumulation.

The primary intended users are DHCD analysts and policymakers who need to identify areas of need, track progress over time, and evaluate whether improvements in housing, health, and wealth outcomes reflect genuine gains for incumbent residents rather than displacement. Each domain index, as well as the Displacement Risk Assessment, is a composite of metrics relevant to that outcome. For example, Housing Stability includes factors like the foreclosure rate, cost burden rate, and overcrowding rates. Health Outcomes includes low birth weight rates, preventable hospitalizations, and the lead exposure rate, all of which are associated with chronic stressors from poor housing conditions. Similarly, Wealth Accumulation  measures rates of homeownership, the home appreciation rate, and the mortgage denial rate.

The Displacement Risk Assessment includes factors such as changes in minority population and education levels, which can indicate potential displacement of existing residents. The Displacement Risk Assessment is intended to identify areas at risk of gentrification and displacement, and to allow for the evaluation of whether improvements in the other indices are genuine gains for incumbent residents.

## Project Structure
The project is organized into the following directories:
- `data/`: Contains raw and processed data files used in the analysis.
- `output/`: Contains generated outputs such as tables, figures, and reports (see [Running the Scripts](#running-the-scripts) for details on what is produced).
- `renv/`: Contains the R environment and dependencies for the project.
- `scripts/`: Contains R scripts for data processing, analysis, and visualization.

## Data Sources
Note: All data sources are at the 2020 census tract level, which is the smallest geographic unit for which the HHW framework can be operationalized given data availability constraints. All data not reported at the 2020 census tract level is crosswalked to the current tract boundaries using either stable tracts (in the case of ACS data) or the USPS tract crosswalk from the HUD website (in the case of vacancy data). For this reason, data prior to 2020 may not be directly comparable to the current tract boundaries, and caution should be exercised when interpreting results from earlier years.

### Data Source Summary Table
| Source | Years Available | Geographic Unit | Access |
|--------|----------------|-----------------|--------|
| American Community Survey (ACS) 5-Year Estimates | 2010–2024 (health and wealth variables: 2015–2024) | Census tract | Public ([Census API](https://api.census.gov/data/key_signup.html); key required) |
| Notice of Intent to Foreclose (NOI) | 2022–2025 | Census tract | Public ([Maryland Open Data](https://opendata.maryland.gov/Housing/Maryland-Notices-of-Intent-to-Foreclose-by-Census-/nme2-wik5/about_data)) |
| USPS/HUD Vacancy | 2015–2025 | Census tract | Restricted — governmental and nonprofit use only ([HUD](https://www.huduser.gov/portal/datasets/usps.html)); registration required |
| Subsidized Housing (NHPD) | 2010–2025 | Property (geocoded to tract) | Public ([NHPD](https://preservationdatabase.org)) |
| School Enrollment/Mobility (MSDE) | 2009–2025 | School attendance zone (crosswalked to tract) | Public ([MSDE](https://reportcard.msde.maryland.gov/Graphs/#/DataDownloads/datadownload)) |
| Health Outcomes (MDE EnviroScreen) | 2024 only | Census tract | Public ([Maryland iMap](https://mdgeodata.md.gov/imap/rest/services/Environment/MD_EnviroScreen/MapServer)) |

### ACS Data
*Years of availability:* 2010-2024 (health and wealth data only available for 2015-2024)

*Description:* The American Community Survey (ACS) is a key data source for this project, providing detailed demographic, social, economic, and housing data. Because the HHW framework relies on census tract-level data, we utilize the ACS 5-year estimates, which offer more reliable data for smaller geographic areas.

### NOI Data
*Years of availability:* 2022-2025

*Description:* The Notice of Intent to Foreclose (NOI) data is sourced from the Maryland Department of Labor. This administrative dataset provides information on foreclosure activity at the census tract level. However, due to privacy concerns, some NOI counts are suppressed in the data, which requires imputation methods to estimate the missing values for a comprehensive analysis.

### Vacancy Data
*Years of availability:* 2015-2025

*Description:* The vacancy data is sourced from a partnership between the United States Postal Service (USPS) and the Department of Housing and Urban Development (HUD). This dataset provides information on residential vacancies at the census tract level, which is a critical component of the Housing Stability Index. The data is updated quarterly, but prior to 2024, data was reported according to 2010 census tract boundaries, requiring a crosswalk to align with current tract boundaries for analysis.

### Subsidized Housing Data
*Years of availability:* 2010-2025

*Description:* The subsidized housing data is sourced from the National Housing Preservation Database (NHPD) which draws from a variety of administrative datasets, including the HUD Picture of Subsidized Households. This dataset provides information on the number of subsidized housing units at the census tract level.

### School Enrollment Data
*Years of availability:* 2009-2025
*Description:* The school enrollment data is sourced from the Maryland State Department of Education (MSDE) and provides information on the number of students who annually enter and withdraw from public schools at the census tract level. Since school attendance boundaries do not align with census tract boundaries, the data is crosswalked to the 2020 census tract level using a weighted average based on the proportion of area inside each school boundary that is contained by each census tract.

### Health Data
*Years of availability:* 2024
*Description:* The health data is sourced from the Maryland Department of the Environment and provides information on low birth weight, asthma, and myocardial infarction rates at the census tract level. This data is used to construct a snapshot of the Health Outcomes Index, which in the future will be expanded to multiple years of data as it becomes available.

## Usage

### Requirements
To run the scripts in this repository, you will need the following software, packages, and data:
- R (version 4.0 or higher; developed and tested on R 4.6.0)
- All packages listed in the `renv.lock` file (use `renv::restore()` to install them)
  - **Note:** The `sf` package requires system-level geospatial libraries (GDAL, GEOS, PROJ). On Ubuntu/Debian, install these first with `sudo apt-get install libgdal-dev libgeos-dev libproj-dev`. On macOS, use `brew install gdal`. On Windows, the CRAN binary for `sf` typically bundles these dependencies.
- A key for the Census API to access ACS data (register at [Census Bureau's website](https://api.census.gov/data/key_signup.html)), pasted into a file named `census.key` in the root directory of the project.
- USPS/HUD vacancy data:
  - Available to registered users at [HUD's website](https://www.huduser.gov/portal/datasets/usps.html) for governmental and nonprofit use.
  - Must be named according to the format `usps_vac_YYYY.dbf` and placed in the `data/raw/vacancy/` directory.
- Rural-Urban Commuting Area (RUCA) codes:
  - Download the latest RUCA codes from the [USDA's website](https://www.ers.usda.gov/data-products/rural-urban-commuting-area-codes/) and save the file as `ruca_codes.csv` in the `data/raw/vacancy` directory.
- USPS tract crosswalk:
  - Download the 2019 "2010-2020" USPS tract crosswalk from the [HUD website](https://www.huduser.gov/portal/datasets/census_tract_crosswalk.html) and save the file as `tract_crosswalk.xlsx` in the `data/raw/vacancy` directory.
- National Housing Preservation Database (NHPD) subsidized housing data:
  - Download the latest NHPD data from the [NHPD website](https://preservationdatabase.org) ("All Subsidies") and save the file as `nhpd_subsidies.xlsx` in the `data/raw/subsidized/` directory.
- Maryland State Department of Education (MSDE) school enrollment data:
  - Download the student mobility data from the [MSDE website](https://reportcard.msde.maryland.gov/Graphs/#/DataDownloads/datadownload) for each year and save the files as `Student_Mobility_YYYY.csv` in the `data/raw/msde/` directory.

### Running the Scripts

1. Clone the repository to your local machine.
2. Ensure that you have acquired a Census API key and all required data files are downloaded and placed in the appropriate directories as specified above.
3. Open the R project file (`housing_health_wealth.Rproj`) in RStudio or your preferred R environment.
4. Run the scripts in the following order:
   - `scripts/01_acs_pull.R`: Pulls and processes ACS data for the relevant years.
   - `scripts/02_noi_pull.R`: Pulls and processes NOI data, including imputation for suppressed values.
   - `scripts/03_vacancy_pull.R`: Pulls and processes USPS/HUD vacancy data, including crosswalking to current census tract boundaries.
   - `scripts/04_subsidized_pull.R`: Pulls and processes NHPD subsidized housing data, including crosswalking to current census tract boundaries.
   - `scripts/05_mobility_pull.R`: Pulls and processes MSDE student mobility data, including crosswalking to current census tract boundaries.
   - `scripts/06_health_pull.R`: Pulls and processes health outcome data, including low birth weight, asthma, and myocardial infarction rates.
   - `scripts/07_wealth_pull.R`: Pulls and processes wealth accumulation data, including homeownership rates, home appreciation rates, and mortgage denial rates.
   - `scripts/08_merge_data.R`: Merges all processed datasets into a single analytical dataset for further analysis and index construction, and marks designated Just Communities.
   - `scripts/09_calculate_index.R`: Calculates the Housing Stability Index (HSI).
   - `scripts/10_visualize_data.R`: Creates visualizations of the HSI over time and across census tracts.
5. These may be run together from the `scripts/run_all.R` script, which will execute all the above scripts in order. Note that this may take some time (approximately 6 minutes) to run, and may need to be repeated if you lose internet connection.

### Outputs

After running the scripts, processed data will be saved in `data/clean/` and the following outputs will be saved in `output/`:
* `output/housing_dashboard.html`: An interactive HTML dashboard visualizing the Housing Stability Index (HSI), Health Outcome Index (HOI), and Wealth Accumulation Index (WAI) across Maryland census tracts, with warning flags based on the Displacement Risk Assessment.

#### Known Harmless Warnings
 
The following warnings are expected and can be safely ignored:
 
| Script | Warning | Cause |
|--------|---------|-------|
| `01_acs_pull.R` | `incomplete final line found on '../census.key'` | Missing newline at end of key file |
| `02_noi_pull.R` | `There were 50 or more warnings` | NOI data unavailable prior to 2022 |
| `05_mobility_pull.R` | `attribute variables are assumed to be spatially constant` / `There were 2 warnings in 'mutate()'` | State and county-wide data is ignored during tract crosswalk |
| `09_calculate_index.R` | `There were 34 warnings in 'mutate()'` | Missing values in NOI data |
| `10_visualize_data.R` | `sf layer has inconsistent datum` | Slight CRS mismatch between Maryland boundary and tract shapefiles; does not affect outputs |
 
If you encounter errors beyond these, check that all required data files are present and correctly named, and that your Census API key is valid.

## Methodological Notes
This section provides additional context and explanations for the methods used in the analysis, including data processing, index construction, and visualization techniques. It is intended to help users understand the rationale behind the choices made in the analysis and to facilitate reproducibility of the results.

### American Community Survey (ACS) Data

#### Geographic Harmonization (2010 → 2020 Census Tracts) <!-- omit in toc -->
Since tract boundaries changed between 2010 and 2020, pre-2020 ACS data is mapped to 2020 geographies using the Census Bureau's tract relationship file. Tracts are classified into stability categories—stable, minor boundary change (less than 1% of total area), merge (many-to-one), split (one-to-many), and complex change—based on the share of land area exchanged between 2010 and 2020 tract pairs. Only stable, minor, and merge cases are carried forward for pre-2020 years; splits and complex changes are dropped and left as NA, since reliable aggregation isn't possible. Merges with more than two source tracts are also excluded as too unreliable to aggregate.

#### Aggregating Merged Tracts <!-- omit in toc -->
For tracts that were merged, count variables are summed directly across the constituent 2010 tracts. Median tenure year is aggregated using a weighted average, weighted by total occupied housing units.

#### Building Age Estimation <!-- omit in toc -->
The ACS reports year-built as binned counts, not a continuous variable, and the bin definitions changed across survey years (2010–2014 use one schema, 2015+ use another). A linear interpolation function estimates the median year built from whichever bin schema applies. The resulting median is then converted to an age by subtracting from the survey year.

#### Data Suppression and Reliability Filters <!-- omit in toc -->
Several filters guard against unreliable estimates. Tracts with fewer than 50 households, or where households are missing entirely, have all rate and median variables set to NA. Tracts where more than half of units are group quarters housing (dorms, prisons, barracks, etc.) are similarly suppressed, since standard housing metrics aren't meaningful there. Tracts with more than a third of vacant units classified as seasonal are flagged. Median tenure values outside a plausible range (below 1900 or above the survey year) are treated as suppressed Census codes and set to NA.

#### Derived Variables <!-- omit in toc -->
Cost burden rates are calculated separately for renters, mortgaged owners, and non-mortgaged owners, excluding households that didn't compute housing costs. Overcrowding is split into moderate (1.01–1.50 persons per room) and severe (above 1.50). Demographic change variables—shifts in minority share and bachelor's degree attainment—are computed as five-year percentage point changes, and are only available from 2015 onward given the need for a lagged value.

### Notice of Intent to Foreclose (NOI) Data

#### Imputation of Suppressed Values <!-- omit in toc -->
Because Maryland suppresses tract-level counts of 1–9 to protect privacy, many tracts have missing values. To address this, a proportional allocation method was used: the difference between the statewide NOI total (sourced from the Maryland Department of Labor Foreclosure Data Tracker) and the sum of all observed tract counts was computed for each year, yielding a "missing" statewide count. This remainder was then redistributed to suppressed tracts in proportion to each tract's ACS mortgaged-homeowner count. Because suppressed values by definition fall between 1 and 9, all imputed values were capped at 9.

### Vacancy Data

#### Geographic Harmonization (2010 → 2020 Census Tracts) <!-- omit in toc -->
Since USPS files span 2015–2025 across different Census tract vintages, each year's data is crosswalked to 2020 tract boundaries using residential ratio weights. Years 2019–2023 share a common crosswalk; earlier years each have their own. Post-2023 data passes through unchanged, as it already aligns with 2020 boundaries.

#### Urban/Non-Urban Calibration <!-- omit in toc -->
Urban tracts (RUCA code 1) show strong USPS-ACS correlation (r = 0.767) and use calibrated USPS rates, preserving annual frequency. Non-urban tracts show poor agreement (r < 0.45), so they fall back to ACS vacancy estimates instead.

For urban tracts, USPS rates are linearly calibrated to ACS rates year-by-year via OLS (regressing ACS rate on USPS rate). This corrects for USPS's systematic undercounting relative to ACS. The calibration was validated with leave-one-year-out cross-validation, achieving a 27% RMSE improvement with stable slope estimates (CV = 13.4%).

#### Exclusion of Highly Seasonal Tracts <!-- omit in toc -->
Tracts with more than 33% of vacant units classified as seasonal are excluded from the analysis, as seasonal occupancy patterns make vacancy rates uninterpretable in those areas.

### Subsidized Housing Data

#### Panel Construction <!-- omit in toc -->
Subsidized housing data comes from the National Housing Preservation Database (NHPD). An annual panel spanning 2010–2024 is constructed by filtering properties to those with an active subsidy in each given year—meaning their recorded start date falls on or before that year and their end date, if known, has not yet passed. Properties with no end date are assumed to remain active.

Because a single property can carry multiple overlapping subsidies, counts are deduplicated at the property level by taking the maximum assisted-unit figure across all active subsidies (the maximum overlap assumption). To handle data quality issues, any deduplicated figure that exceeds a property's known total unit count is capped at that total, and properties with no valid unit count are assigned zero.

#### Spatial Crosswalk to Census Tracts <!-- omit in toc -->

Properties are then geocoded to 2020 Maryland census tracts using a point-in-polygon spatial join, and assisted units are summed to the tract level for each year. Finally, tract-level subsidized unit counts are divided by total household counts drawn from the American Community Survey (ACS) to produce an annual share of subsidized units per tract.

### School Mobility Data

#### Spatial Crosswalk to Census Tracts <!-- omit in toc -->
Since census block groups (which make up census tracts) and school attendance zones overlap arbitrarily, the script intersects the two layers and computes an area ratio for each block group–zone pair. This ratio is used to apportion block group population into each school's attendance zone, assuming uniform population density within block groups. Then, for each year, the rate of students withdrawing from each school is aggregated to the census tract level by summing across all attendance zones that intersect a given tract, weighted by the area ratio.

#### Handling of Suppressed Values <!-- omit in toc -->
The raw MSDE enrollment data suppresses small values using symbols (`<= 5.0`, `*`) and flags extremes (`> 95.0`). The script applies a conservative substitution of 5% for suppressed low values and 95% for extreme high values, rather than dropping or imputing those records.

### Maryland Health Data

#### Limitations <!-- omit in toc -->
Currently, data on low birth weight, asthma, and myocardial infarction is only available for 2024. As additional years of data become available, the Health Outcomes Index will be expanded to include multiple years of data, but for now the index functions as a snapshot and proof of concept for the HHW framework.

### Index Construction

#### Housing Stability Index (HSI) <!-- omit in toc -->
The HSI is a composite index scored 0–100 (higher = more stable) built from three sub-domains, which were selected based on a Principal Component Analysis (PCA) of the input metrics:

* Household Strain — averages cost burden rate, median tenure, and median building age
* Overcrowding — averages overcrowding and severe overcrowding rates
* Market Distress — averages vacancy rate, NOI per 1,000 owners, and severe cost burden rate

Each input metric is min-max scaled to 0–100 within year, with directionally negative indicators (e.g. cost burden) inverted so that higher always means better. The sub-domain scores are then averaged into a final raw score. Tracts missing 3 or more input variables are excluded (score set to NA). The final HSI score is then used to compute a within-year z-score and percentile rank for cross-tract benchmarking.

#### Wealth Accumulation Index (WAI) <!-- omit in toc -->
The WAI has not yet been implemented.

#### Health Outcomes Index (HOI) <!-- omit in toc -->
The HOI is a composite index that averages the percentile ranks of five indicators:

* Uninsured rate
* Pre-1980 housing stock (a proxy for lead exposure)
* Low birth weight
* Asthma
* Myocardial infarction

The composite is inverted (subtracted from 100) so that higher scores reflect better health outcomes. Tracts missing 3 or more of the five metrics are excluded. A final percentile rank across all tracts produces the HOI score.

#### Displacement Risk Assessment <!-- omit in toc -->
Each tract receives a score of 0–3 based on three demographic shift signals, computed as within-year z-scores:
Signal                              | Threshold      | Score
---                                 | ---            | ---
Minority population change          | z-score < -0.5 | 1
Bachelor's degree attainment change | z-score > 0.5  | 1
School withdrawal rate change       | z-score > 1    | 1

Scores map to risk categories: 0 → Stable, 1 → Low, 2 → Moderate, 3 → Severe. Missing values in the demographic change variables are treated as non-qualifying (coalesced to 0) rather than propagated as NA.

## Contact

This project is maintained by the Division of Just Communities at the Maryland Department of Housing and Community Development. For questions about the methodology, data access, or to report issues, contact Scott Pawley at his [LinkedIn profile](https://www.linkedin.com/in/scott-pawley/), the team at the Just Communities' [website](https://dhcd.maryland.gov/Just-Communities/Pages/default.aspx), or open an issue in this repository.

## Bibliography

Maryland Department of the Environment. (2026). *MD EnviroScreen* [Data set]. https://mdgeodata.md.gov/imap/rest/services/Environment/MD_EnviroScreen/MapServer

Maryland Department of Labor. (2026). *Maryland Notices of Intent to Foreclose by Census Tract* [Data set]. https://opendata.maryland.gov/Housing/Maryland-Notices-of-Intent-to-Foreclose-by-Census-/nme2-wik5/about_data

Maryland State Department of Education. (2026). *Student Mobility Data* [Data set]. https://reportcard.msde.maryland.gov/Graphs/#/DataDownloads/datadownload

Public and Affordable Housing Research Corporation & National Low Income Housing Coalition. (2026). *National Housing Preservation Database* [Data set]. https://preservationdatabase.org

Schroeder, J., Van Riper, D., Manson, S., Knowles, K., Kugler, T., Roberts, F., & Ruggles, S. (2025). *IPUMS National Historical Geographic Information System: Version 20.0* [Data set]. http://doi.org/10.18128/D050.V20.0 

U.S. Census Bureau. (2010–2024). *American Community Survey 5-Year Estimates* [Data set]. U.S. Department of Commerce. https://www.data.census.gov

U.S. Department of Agriculture, Economic Research Service. (2026). *Rural-Urban Commuting Area Codes* [Data set]. https://www.ers.usda.gov/data-products/rural-urban-commuting-area-codes/

U.S. Department of Housing and Urban Development. (2026). *HUD Aggregated USPS administrative data on address vacancies (2008–2025)* [Data set]. Office of Policy Development and Research. https://www.huduser.gov/portal/datasets/usps.html

U.S. Department of Housing and Urban Development. (2019). *2010-2020 HUD USPS Tract Crosswalk* [Data set]. Office of Policy Development and Research. https://www.huduser.gov/portal/datasets/census_tract_crosswalk.html