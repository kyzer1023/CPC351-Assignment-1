# Q1(a): clean and standardise the six supplied course registration lists.

q1_expected_courses <- c("CCS592", "CDS501", "CDS506", "CDS512", "CDS521", "CDS523")

q1_find_project_root <- function() {
  file_argument <- grep("^--file=", commandArgs(), value = TRUE)
  starting_points <- getwd()
  if (length(file_argument) > 0L) {
    starting_points <- c(dirname(sub("^--file=", "", file_argument[[1L]])), starting_points)
  }
  for (start in starting_points) {
    candidate <- normalizePath(start, winslash = "/", mustWork = TRUE)
    repeat {
      if (file.exists(file.path(candidate, "CPC351-Assignment-1.Rproj")) &&
          file.exists(file.path(candidate, "assignment_files", "run_assignment.R"))) {
        return(candidate)
      }
      parent <- dirname(candidate)
      if (identical(parent, candidate)) break
      candidate <- parent
    }
  }
  stop("Cannot locate the assignment folder. Run this script from the project or by its path.",
       call. = FALSE)
}

read_q1_registration_lists <- function(project_root) {
  input_directory <- file.path(project_root, "assignment_files")
  files <- sort(list.files(
    input_directory,
    pattern = "^Q1_[[:alnum:]]+\\.txt$",
    full.names = TRUE
  ))
  course_codes <- sub("^Q1_(.+)\\.txt$", "\\1", basename(files))
  if (!setequal(course_codes, q1_expected_courses) || length(files) != length(q1_expected_courses)) {
    stop(
      "Q1 requires exactly these six files beside the scripts: ",
      paste(paste0("Q1_", q1_expected_courses, ".txt"), collapse = ", "),
      call. = FALSE
    )
  }
  registrations <- lapply(files, readLines, warn = FALSE, encoding = "UTF-8")
  names(registrations) <- course_codes
  registrations[q1_expected_courses]
}

normalize_q1_student_ids <- function(values) {
  raw <- trimws(as.character(values))
  digits <- gsub("[^0-9]", "", raw)
  valid <- nzchar(digits)
  normalized_digits <- sub("^0+", "", digits[valid])
  normalized_digits[!nzchar(normalized_digits)] <- "0"
  padding <- pmax(0L, 3L - nchar(normalized_digits))
  valid_ids <- paste0("NAME", vapply(seq_along(normalized_digits), function(i) {
    paste0(strrep("0", padding[[i]]), normalized_digits[[i]])
  }, character(1)))
  clean <- rep(NA_character_, length(raw))
  clean[valid] <- valid_ids
  list(raw = raw, clean = clean, valid = valid)
}

clean_q1_registrations <- function(registrations) {
  if (!is.list(registrations) || is.null(names(registrations)) ||
      !setequal(names(registrations), q1_expected_courses)) {
    stop("registrations must be a named list containing the six Q1 courses.", call. = FALSE)
  }

  cleaned <- setNames(vector("list", length(q1_expected_courses)), q1_expected_courses)
  audit_rows <- vector("list", length(q1_expected_courses))

  for (i in seq_along(q1_expected_courses)) {
    course <- q1_expected_courses[[i]]
    values <- registrations[[course]]
    normalized <- normalize_q1_student_ids(values)
    duplicate <- duplicated(normalized$clean)
    duplicate[!normalized$valid] <- FALSE
    ids <- normalized$clean[normalized$valid & !duplicate]
    cleaned[[course]] <- sort(ids)

    audit_rows[[i]] <- data.frame(
      course = course,
      raw_rows = length(values),
      blank_rows = sum(!nzchar(normalized$raw)),
      invalid_id_rows = sum(!normalized$valid & nzchar(normalized$raw)),
      normalized_rows = sum(normalized$valid),
      standardized_rows = sum(normalized$valid &
                                normalized$raw != normalized$clean),
      duplicate_rows_removed = sum(duplicate),
      cleaned_students = length(cleaned[[course]]),
      stringsAsFactors = FALSE
    )
  }

  audit <- do.call(rbind, audit_rows)
  rownames(audit) <- NULL
  list(courses = cleaned, audit = audit)
}

write_q1_cleaning_outputs <- function(cleaning_result, project_root) {
  output_dir <- file.path(project_root, "outputs", "q1")
  list_dir <- file.path(output_dir, "cleaned_lists")
  dir.create(list_dir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(cleaning_result$audit,
                   file.path(output_dir, "q1_cleaning_audit.csv"),
                   row.names = FALSE)
  saveRDS(cleaning_result$courses, file.path(output_dir, "courses_clean.rds"))
  for (course in names(cleaning_result$courses)) {
    writeLines(
      cleaning_result$courses[[course]],
      file.path(list_dir, paste0("Q1_", course, "_cleaned.txt")),
      useBytes = TRUE
    )
  }
  invisible(output_dir)
}

run_q1_cleaning <- function(project_root = q1_find_project_root()) {
  result <- clean_q1_registrations(read_q1_registration_lists(project_root))
  write_q1_cleaning_outputs(result, project_root)
  result
}

if (sys.nframe() == 0L) {
  root <- q1_find_project_root()
  result <- run_q1_cleaning(root)
  print(result$audit, row.names = FALSE)
  message("Q1(a): cleaned registration lists written to outputs/q1/cleaned_lists/.")
}
