<!-- omit in toc -->
# Housing, Health, and Wealth Analyzer

This repository contains code and documentation for the Housing, Health, and Wealth Analyzer project. The project aims to analyze the relationships between housing conditions, health outcomes, and wealth indicators across Maryland census tracts.

<!-- omit in toc -->
## Table of Contents
- [Project Overview](#project-overview)
- [Project Structure](#project-structure)
- [Data Sources](#data-sources)
  - [ACS Data](#acs-data)
  - [NOI Data](#noi-data)
  - [Vacancy Data](#vacancy-data)
- [Usage](#usage)
  - [Requirements](#requirements)
  - [Running the Scripts](#running-the-scripts)
- [Methodology](#methodology)

## Project Overview
The Housing, Health, and Wealth Analyzer project is designed to operationalize the Maryland Departmnt of Housing and Community Development's (DHCD) Housing, Health, and Wealth (HHW) framework. The framework aims to forward DHCD's mission of providing every Marylander “the opportunity to live and prosper in affordable, lovable and just communities” across three domains: Housing Stability, Health Outcomes, and Wealth Accumulation.

Each domain (Housing Stability, Health Outcomes, and Wealth Accumulation), as well as the Displacement Risk Assessment, would be a combination of metrics relevant to each outcome. For example, Housing Stability would include factors like the eviction rate, foreclosure rate, cost burden, and overcrowding. Health Outcomes would include low birth weight rates, preventable hospitalizations, and the childhood lead poisoning rate, all of which are associated with chronic stressors from poor housing conditions. Similarly, wealth accumulation would measure rates of homeownership, the home appreciation rate, and the mortgage denial rate.

As there are constraints on data availability, this pilot project focuses on the Housing Stability Index, which is primarily composed of publicly available Census and administrative data. The Health Outcomes and Wealth Accumulation indices will be developed in future phases of the project as more data becomes available.

## Project Structure
The project is organized into the following directories:
- `data/`: Contains raw and processed data files used in the analysis.
- `scripts/`: Contains R scripts for data processing, analysis, and visualization.
- `output/`: Contains generated outputs such as tables, figures, and reports.

## Data Sources

### ACS Data
*Years of availability:* 2020-2024 (current tract boundaries)

*Description:* The American Community Survey (ACS) is a key data source for this project, providing detailed demographic, social, economic, and housing data. Because the HHW framework relies on census tract-level data, we utilize the ACS 5-year estimates, which offer more reliable data for smaller geographic areas.

### NOI Data
*Years of availability:* 2022-2025

*Description:* The Notice of Intent to Foreclose (NOI) data is sourced from the Maryland Department of Labor. This administrative dataset provides information on foreclosure activity at the census tract level. However, due to privacy concerns, some NOI counts are suppressed in the data, which requires imputation methods to estimate the missing values for a comprehensive analysis.

### Vacancy Data
*Years of availability:* 2020-2025

*Description:* The vacancy data is sourced from a partnership between the United States Postal Service (USPS) and the Department of Housing and Urban Development (HUD). This dataset provides information on residential vacancies at the census tract level, which is a critical component of the Housing Stability Index. The data is updated quarterly, but prior to 2024, data was reported according to 2010 census tract boundaries, requiring a crosswalk to align with current tract boundaries for analysis.

## Usage

### Requirements
To run the scripts in this repository, you will need the following software, packages, and data:
- R (version 4.0 or higher)
- All packages listed in the `renv.lock` file (use `renv::restore()` to install them)
- USPS/HUD vacancy data:
  - Available to registered users at [HUD's website](https://www.huduser.gov/portal/datasets/usps.html) for governmental and nonprofit use.
  - Must be named according to the format `usps_vac_YYYY.dbf` and placed in the `data/raw/vacancy/` directory.
- Rural-Urban Commuting Area (RUCA) codes:
  - Download the latest RUCA codes from the [USDA's website](https://www.ers.usda.gov/data-products/rural-urban-commuting-area-codes/) and save the file as `ruca_codes.csv` in the `data/raw/vacancy` directory.
- USPS tract crosswalk:
  - Download the 2019 "2010-2020" USPS tract crosswalk from the [HUD website](https://www.huduser.gov/portal/datasets/census_tract_crosswalk.html) and save the file as `tract_crosswalk.xlsx` in the `data/raw/vacancy` directory.

### Running the Scripts
1. Clone the repository to your local machine.
2. Open the R project file (`housing_health_wealth.Rproj`) in RStudio.
3. Run the scripts in the following order:
   - `scripts/01_acs_pull.R`: Pulls and processes ACS data for the relevant years.
   - `scripts/02_noi_pull.R`: Pulls and processes NOI data, including imputation for suppressed values.
   - `scripts/03_vacancy_pull.R`: Pulls and processes USPS/HUD vacancy data, including crosswalking to current census tract boundaries.
   - `scripts/04_merge_data.R`: Merges all processed datasets into a single analytical dataset for further analysis and index construction.
4. After running the scripts, the processed data will be saved in the `data/clean/` directory. You can then proceed with analysis and visualization using the merged dataset.
5. Refer to the `output/` directory for generated tables and figures based on the processed data.

## Methodology