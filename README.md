<!-- omit in toc -->
# Housing, Health, and Wealth Analyzer

This repository contains code and documentation for the Housing, Health, and Wealth Analyzer project. The project aims to analyze the relationships between Housing Stability, Health Outcomes, and Wealth Accumulation across Maryland census tracts.

<!-- omit in toc -->
## Table of Contents
- [Project Overview](#project-overview)
- [Project Structure](#project-structure)
- [Data Sources](#data-sources)
  - [ACS Data](#acs-data)
  - [NOI Data](#noi-data)
  - [Vacancy Data](#vacancy-data)
  - [Subsidized Housing Data](#subsidized-housing-data)
- [Usage](#usage)
  - [Requirements](#requirements)
  - [Running the Scripts](#running-the-scripts)
- [Methodology](#methodology)
- [Bibliography](#bibliography)

## Project Overview
The Housing, Health, and Wealth Analyzer project is designed to operationalize the Maryland Departmnt of Housing and Community Development's (DHCD) Housing, Health, and Wealth (HHW) framework. The framework aims to forward DHCD's mission of providing every Marylander “the opportunity to live and prosper in affordable, lovable and just communities” across three domains: Housing Stability, Health Outcomes, and Wealth Accumulation.

Each domain (Housing Stability, Health Outcomes, and Wealth Accumulation), as well as the Displacement Risk Assessment, would be a combination of metrics relevant to each outcome. For example, Housing Stability would include factors like the eviction rate, foreclosure rate, cost burden, and overcrowding. Health Outcomes would include low birth weight rates, preventable hospitalizations, and the childhood lead poisoning rate, all of which are associated with chronic stressors from poor housing conditions. Similarly, wealth accumulation would measure rates of homeownership, the home appreciation rate, and the mortgage denial rate.

As there are constraints on data availability, this pilot project focuses on the Housing Stability Index, which is primarily composed of publicly available Census and administrative data. The Health Outcomes and Wealth Accumulation indices will be developed in future phases of the project as more data becomes available.

## Project Structure
The project is organized into the following directories:
- `data/`: Contains raw and processed data files used in the analysis.
- `output/`: Contains generated outputs such as tables, figures, and reports.
- `renv/`: Contains the R environment and dependencies for the project.
- `scripts/`: Contains R scripts for data processing, analysis, and visualization.

## Data Sources
Note: All data sources are at the 2020 census tract level, which is the smallest geographic unit for which the HHW framework can be operationalized given data availability constraints. All data not reported at the 2020 census tract level is crosswalked to the current tract boundaries using either stable tracts (in the case of ACS data) or the USPS tract crosswalk from the HUD website (in the case of vacancy data). For this reason, data prior to 2020 may not be directly comparable to the current tract boundaries, and caution should be exercised when interpreting results from earlier years.

### ACS Data
*Years of availability:* 2010-2024 (current tract boundaries)

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

## Usage

### Requirements
To run the scripts in this repository, you will need the following software, packages, and data:
- R (version 4.0 or higher)
- All packages listed in the `renv.lock` file (use `renv::restore()` to install them)
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

### Running the Scripts
1. Clone the repository to your local machine.
2. Open the R project file (`housing_health_wealth.Rproj`) in RStudio.
3. Run the scripts in the following order:
   - `scripts/01_acs_pull.R`: Pulls and processes ACS data for the relevant years.
   - `scripts/02_noi_pull.R`: Pulls and processes NOI data, including imputation for suppressed values.
   - `scripts/03_vacancy_pull.R`: Pulls and processes USPS/HUD vacancy data, including crosswalking to current census tract boundaries.
   - `scripts/04_subsidized_pull.R`: Pulls and processes NHPD subsidized housing data, including crosswalking to current census tract boundaries.
   - `scripts/05_merge_data.R`: Merges all processed datasets into a single analytical dataset for further analysis and index construction, and marks designated Just Communities.
   - `scripts/06_calculate_index.R`: Calculates the Housing Stability Index (HSI).
   - `scripts/07_visualize_data.R`: Creates visualizations of the HSI over time and across census tracts.
4. After running the scripts, the processed data will be saved in the `data/clean/` directory. You can then proceed with analysis and visualization using the merged dataset.
5. Refer to the `output/` directory for generated tables and figures based on the processed data.

## Methodology

## Bibliography

Maryland Department of Labor. (2026). *Maryland Notices of Intent to Foreclose by Census Tract* [Data set]. https://opendata.maryland.gov/Housing/Maryland-Notices-of-Intent-to-Foreclose-by-Census-/nme2-wik5/about_data

Public and Affordable Housing Research Corporation & National Low Income Housing Coalition. (2026). *National Housing Preservation Database* [Data set]. https://preservationdatabase.org

Schroeder, J., Van Riper, D., Manson, S., Knowles, K., Kugler, T., Roberts, F., & Ruggles, S. (2025). *IPUMS National Historical Geographic Information System: Version 20.0* [Data set]. http://doi.org/10.18128/D050.V20.0 

U.S. Census Bureau. (2016–2024). *American Community Survey 5-Year Estimates* [Data set]. U.S. Department of Commerce. https://www.data.census.gov

U.S. Department of Agriculture, Economic Research Service. (2026). *Rural-Urban Commuting Area Codes* [Data set]. https://www.ers.usda.gov/data-products/rural-urban-commuting-area-codes/

U.S. Department of Housing and Urban Development (HUD). (2026). *HUD Aggregated USPS administrative data on address vacancies (2008–2025)* [Data set]. Office of Policy Development and Research. https://www.huduser.gov/portal/datasets/usps.html

U.S. Department of Housing and Urban Development. (2019). *2010-2020 HUD USPS Tract Crosswalk* [Data set]. Office of Policy Development and Research. https://www.huduser.gov/portal/datasets/census_tract_crosswalk.html