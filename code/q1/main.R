# Q1 baseline: read supplied registrations and describe the untouched inputs.

read_q1_registration_lists <- function(project_root) {
  input_directory <- file.path(project_root, "data", "raw", "q1")
  files <- sort(list.files(input_directory, pattern = "^Q1_[[:alnum:]]+\\.txt$",
                          full.names = TRUE))
  course_codes <- sub("^Q1_(.+)\\.txt$", "\\1", basename(files))
  expected_courses <- c("CCS592", "CDS501", "CDS506", "CDS512", "CDS521", "CDS523")

  if (!setequal(course_codes, expected_courses)) {
    stop("Q1 requires the six supplied registration lists in data/raw/q1/.",
         call. = FALSE)
  }

  registrations <- lapply(files, function(path) {
    readLines(path, warn = FALSE, encoding = "UTF-8")
  })
  names(registrations) <- course_codes
  registrations
}

inspect_q1_inputs <- function(project_root) {
  registrations <- read_q1_registration_lists(project_root)
  course_codes <- names(registrations)

  inventory <- data.frame(
    course = course_codes,
    file = paste0("data/raw/q1/Q1_", course_codes, ".txt"),
    raw_rows = vapply(registrations, length, integer(1)),
    blank_rows = vapply(registrations, function(rows) {
      as.integer(sum(!nzchar(trimws(rows))))
    }, integer(1)),
    exact_duplicate_rows = vapply(registrations, function(rows) {
      as.integer(sum(duplicated(rows)))
    }, integer(1)),
    row.names = NULL,
    stringsAsFactors = FALSE
  )

  destination <- file.path(project_root, "outputs", "q1", "input_inventory.csv")
  write_output_csv(inventory, destination)
  message("Q1: raw input inventory written to ", destination)
  message("Q1: identifiers are unchanged; cleaning and scheduling are pending.")

  invisible(list(registrations = registrations, inventory = inventory))
}
