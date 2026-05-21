# ClinicalTrials.gov Study Fetcher for GitLab CI with Hereby

A small R script that queries the **ClinicalTrials.gov API v2**, paginates through all available results for a condition, and returns a tidy table of study metadata.

This project is suitable for running with **Hereby** in a GitLab repository to automate data pulls and optionally export results to CSV.

## Features

- Queries ClinicalTrials.gov API v2
- Handles API pagination automatically
- Extracts key study fields into a tidy tibble
- Works for any condition string
- Can print results or write them to CSV
- Easy to run locally or in GitLab CI

## Script Overview

The script:

- Loads required R packages
- Defines a helper operator `%||%` for default fallback values
- Defines `get_ctgov_studies()` to:
  - call the ClinicalTrials.gov studies endpoint
  - fetch all pages using `nextPageToken`
  - flatten selected fields into a tibble
- Fetches studies for `"Lupus Nephritis"`
- Prints the full result set
- Optionally writes the data to a CSV file

## Requirements

Make sure you have R installed along with these packages:

- `httr2`
- `jsonlite`
- `dplyr`
- `purrr`
- `tibble`
- `readr`

You can install them with:

```r
install.packages(c("httr2", "jsonlite", "dplyr", "purrr", "tibble", "readr"))
```

## Project Structure

Example layout:

```text
.
├── hereby
├── script.R
└── README.md
```

## Example R Script

Save your script as `script.R`:

```r
library(httr2)
library(jsonlite)
library(dplyr)
library(purrr)
library(tibble)
library(readr)

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

get_ctgov_studies <- function(condition, page_size = 100) {
  fetch_page <- function(page_token = NULL) {
    req <- request("https://clinicaltrials.gov/api/v2/studies") |>
      req_url_query(
        `query.cond` = condition,
        pageSize = page_size
      )
    
    if (!is.null(page_token) && !identical(page_token, "")) {
      req <- req |> req_url_query(pageToken = page_token)
    }
    
    resp <- req_perform(req)
    txt <- resp_body_string(resp)
    
    jsonlite::parse_json(txt, simplifyVector = FALSE)
  }
  
  all_studies <- list()
  token <- NULL
  
  repeat {
    dat <- fetch_page(token)
    
    page_studies <- dat$studies %||% list()
    
    if (length(page_studies) > 0) {
      all_studies <- append(all_studies, page_studies)
    }
    
    token <- dat$nextPageToken %||% NULL
    
    if (is.null(token) || identical(token, "")) {
      break
    }
  }
  
  tibble(
    nct_id = map_chr(
      all_studies,
      function(s) s$protocolSection$identificationModule$nctId %||% NA_character_
    ),
    brief_title = map_chr(
      all_studies,
      function(s) s$protocolSection$identificationModule$briefTitle %||% NA_character_
    ),
    official_title = map_chr(
      all_studies,
      function(s) s$protocolSection$identificationModule$officialTitle %||% NA_character_
    ),
    overall_status = map_chr(
      all_studies,
      function(s) s$protocolSection$statusModule$overallStatus %||% NA_character_
    ),
    study_type = map_chr(
      all_studies,
      function(s) s$protocolSection$designModule$studyType %||% NA_character_
    ),
    phase = map_chr(
      all_studies,
      function(s) paste(s$protocolSection$designModule$phases %||% character(0), collapse = "; ")
    ),
    enrollment = map_chr(
      all_studies,
      function(s) as.character(s$protocolSection$designModule$enrollmentInfo$count %||% NA)
    ),
    conditions = map_chr(
      all_studies,
      function(s) paste(s$protocolSection$conditionsModule$conditions %||% character(0), collapse = "; ")
    ),
    interventions = map_chr(
      all_studies,
      function(s) {
        ints <- s$protocolSection$armsInterventionsModule$interventions %||% list()
        if (length(ints) == 0) return(NA_character_)
        vals <- vapply(ints, function(z) z$name %||% NA_character_, character(1))
        vals <- vals[!is.na(vals) & nzchar(vals)]
        if (length(vals) == 0) NA_character_ else paste(vals, collapse = "; ")
      }
    ),
    sponsor = map_chr(
      all_studies,
      function(s) s$protocolSection$sponsorCollaboratorsModule$leadSponsor$name %||% NA_character_
    ),
    start_date = map_chr(
      all_studies,
      function(s) s$protocolSection$statusModule$startDateStruct$date %||% NA_character_
    ),
    completion_date = map_chr(
      all_studies,
      function(s) s$protocolSection$statusModule$completionDateStruct$date %||% NA_character_
    ),
    study_url = map_chr(
      all_studies,
      function(s) {
        nct <- s$protocolSection$identificationModule$nctId %||% NA_character_
        if (is.na(nct)) NA_character_ else paste0("https://clinicaltrials.gov/study/", nct)
      }
    )
  )
}

results <- get_ctgov_studies("Lupus Nephritis")

print(results, n = nrow(results))

# write_csv(results, "lupus_nephritis_clinical_trials.csv")
```

## Using Hereby

If you want to run this from a `hereby` script, create a file named `hereby` in the repository root:

```bash
#!/usr/bin/env bash
set -euo pipefail

Rscript script.R
```

Make it executable:

```bash
chmod +x hereby
```

Then run:

```bash
./hereby
```

## GitLab CI Example

If you want GitLab CI to run this automatically, add a `.gitlab-ci.yml` like this:

```yaml
image: rocker/tidyverse:latest

stages:
  - run

clinicaltrials_fetch:
  stage: run
  script:
    - Rscript -e 'install.packages(c("httr2","jsonlite","dplyr","purrr","tibble","readr"), repos="https://cloud.r-project.org")'
    - Rscript script.R
  artifacts:
    when: always
    paths:
      - lupus_nephritis_clinical_trials.csv
```

## Output Columns

The returned tibble includes:

- `nct_id`
- `brief_title`
- `official_title`
- `overall_status`
- `study_type`
- `phase`
- `enrollment`
- `conditions`
- `interventions`
- `sponsor`
- `start_date`
- `completion_date`
- `study_url`

## Customizing the Query

To fetch another condition, change:

```r
results <- get_ctgov_studies("Lupus Nephritis")
```

For example:

```r
results <- get_ctgov_studies("Breast Cancer")
```

You can also change the page size:

```r
results <- get_ctgov_studies("Lupus Nephritis", page_size = 50)
```

## Saving to CSV

Uncomment the last line to export results:

```r
write_csv(results, "lupus_nephritis_clinical_trials.csv")
```

## Notes

- The script depends on the current structure of the ClinicalTrials.gov API v2 response.
- Some fields may be missing for some studies, so the script safely fills those with `NA`.
- API result counts and fields may change over time.

