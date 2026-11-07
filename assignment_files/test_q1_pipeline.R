# Q1 integration checks for cleaning, conflict counts, and both timetables.

test_q1_pipeline <- function() {
  script_dir <- normalizePath("assignment_files", winslash = "/", mustWork = TRUE)
  source(file.path(script_dir, "q1_clean.R"), local = TRUE)
  source(file.path(script_dir, "q1_conflict.R"), local = TRUE)
  source(file.path(script_dir, "q1_schedule.R"), local = TRUE)
  source(file.path(script_dir, "q1_main.R"), local = TRUE)

  root <- q1_find_project_root()
  result <- run_q1_pipeline(root, verbose = FALSE)
  courses <- result$cleaning$courses
  conflict <- result$conflict_matrix
  initial <- result$schedule$initial_timetable
  updated <- result$schedule$timetable

  stopifnot(
    identical(length(courses), 6L),
    identical(sum(lengths(courses)), 265L),
    identical(result$cleaning$audit$duplicate_rows_removed[
      result$cleaning$audit$course == "CDS521"
    ], 1L),
    all(grepl("^NAME[0-9]{3,}$", unlist(courses))),
    isSymmetric(conflict),
    identical(as.integer(diag(conflict)), as.integer(lengths(courses))),
    identical(unname(conflict["CDS506", "CDS521"]), 23L),
    identical(unname(conflict["CDS501", "CDS523"]), 0L),
    identical(result$schedule$initial_minimum_sessions, 5L),
    isFALSE(result$schedule$original_eight_slots_sufficient),
    identical(result$schedule$minimum_days, 5L),
    nrow(initial) == 6L,
    nrow(updated) == 6L,
    all(initial$students <= initial$capacity),
    all(updated$students <= updated$capacity)
  )

  for (i in seq_len(nrow(initial) - 1L)) {
    for (j in seq.int(i + 1L, nrow(initial))) {
      stopifnot(
        initial$day[[i]] != initial$day[[j]] ||
          initial$period[[i]] != initial$period[[j]] ||
          conflict[initial$course[[i]], initial$course[[j]]] == 0L
      )
      stopifnot(
        updated$day[[i]] != updated$day[[j]] ||
          conflict[updated$course[[i]], updated$course[[j]]] == 0L
      )
    }
  }

  output_files <- c(
    "q1_cleaning_audit.csv",
    "conflict_matrix.csv",
    "conflict_pairs.csv",
    "concurrent_conflict_timetable.csv",
    "examination_timetable.csv",
    "timetable_validation.csv"
  )
  stopifnot(all(file.exists(file.path(root, "outputs", "q1", output_files))))
  cat("ALL Q1 PIPELINE CHECKS PASSED.\n")
  invisible(TRUE)
}

if (sys.nframe() == 0L) test_q1_pipeline()
