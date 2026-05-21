
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
