# Q1 integration checks for cleaning, conflict counts, and both timetables.

test_q1_pipeline <- function() {
  script_dir <- normalizePath("assignment_files", winslash = "/", mustWork = TRUE)
  source(file.path(script_dir, "q1_clean.R"), local = TRUE)
  source(file.path(script_dir, "q1_conflict.R"), local = TRUE)
  source(file.path(script_dir, "q1_schedule.R"), local = TRUE)
  source(file.path(script_dir, "q1_main.R"), local = TRUE)

  root <- q1_find_project_root()
  console <- capture.output(result <- suppressMessages(run_q1_pipeline(root)))
  courses <- result$cleaning$courses
  conflict <- result$conflict_matrix
  initial <- result$schedule$initial_timetable
  updated <- result$schedule$timetable

  stopifnot(
    identical(length(courses), 6L),
    identical(unname(lengths(courses)), c(38L, 54L, 38L, 64L, 65L, 6L)),
    identical(sum(lengths(courses)), 265L),
    length(unique(unlist(courses))) == 167L,
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
    identical(result$schedule$minimum_days, 5L)
  )

  check_schedule <- function(timetable, registrations, no_back_to_back = FALSE) {
    # Build the assignment's slot layout separately from the scheduling code.
    layout <- data.frame(
      day = rep(seq_len(max(timetable$day)), each = 4L),
      period = rep(c("Morning", "Morning", "Afternoon", "Afternoon"),
                   max(timetable$day)),
      venue = rep(c("Venue 1", "Venue 2"), 2L * max(timetable$day)),
      capacity = rep(c(40L, 70L), 2L * max(timetable$day))
    )
    slots <- layout[timetable$slot, ]
    stopifnot(
      nrow(timetable) == length(registrations),
      setequal(timetable$course, names(registrations)),
      !anyDuplicated(timetable$course),
      !anyDuplicated(timetable$slot),
      !anyDuplicated(timetable[c("day", "period", "venue")]),
      all(timetable$day == slots$day),
      all(timetable$period == slots$period),
      all(timetable$venue == slots$venue),
      all(timetable$capacity == slots$capacity),
      all(timetable$students == lengths(registrations)[timetable$course]),
      all(timetable$students <= slots$capacity)
    )

    # Check each student's exams directly from memberships, independently of
    # both the conflict matrix and the production validation functions.
    for (student in unique(unlist(registrations))) {
      enrolled <- names(registrations)[vapply(registrations, function(ids) {
        student %in% ids
      }, logical(1))]
      exams <- timetable[timetable$course %in% enrolled, ]
      stopifnot(!anyDuplicated(exams[c("day", "period")]))
      if (no_back_to_back) stopifnot(!anyDuplicated(exams$day))
    }
    invisible(TRUE)
  }

  check_schedule(initial, courses)
  check_schedule(updated, courses, no_back_to_back = TRUE)
  stopifnot(
    length(unique(paste(initial$day, initial$period))) == 5L,
    length(unique(updated$day)) == 5L,
    max(initial$day) == 3L,
    any(initial$slot > 8L)
  )

  # A group of five pairwise-conflicting courses proves that four periods
  # cannot work for (c), and fewer than five days cannot work for (d).
  # Together with the valid schedules above, this verifies the minimum claims.
  five_course_groups <- combn(names(courses), 5L, simplify = FALSE)
  stopifnot(any(vapply(five_course_groups, function(group) {
    overlaps <- conflict[group, group]
    all(overlaps[upper.tri(overlaps)] > 0L)
  }, logical(1))))

  output_files <- c(
    "q1_cleaning_audit.csv",
    "conflict_matrix.csv",
    "conflict_pairs.csv",
    "concurrent_conflict_timetable.csv",
    "examination_timetable.csv",
    "timetable_validation.csv"
  )
  stopifnot(all(file.exists(file.path(root, "outputs", "q1", output_files))))

  initial_csv <- read.csv(file.path(root, "outputs/q1/concurrent_conflict_timetable.csv"))
  updated_csv <- read.csv(file.path(root, "outputs/q1/examination_timetable.csv"))
  validation_csv <- read.csv(file.path(root, "outputs/q1/timetable_validation.csv"))
  stopifnot(
    identical(initial_csv, initial),
    identical(updated_csv, updated),
    identical(validation_csv, result$validation),
    validation_csv$courses_scheduled == nrow(initial_csv),
    validation_csv$initial_time_periods_required == nrow(unique(initial_csv[c("day", "period")])),
    validation_csv$updated_days_required == length(unique(updated_csv$day)),
    !validation_csv$original_eight_slots_sufficient,
    validation_csv$back_to_back_conflicts == 0L,
    validation_csv$capacity_violations == 0L
  )
  # The console must display the same tables and conclusions as the CSV files.
  console_text <- paste(console, collapse = "\n")
  for (table in list(initial_csv, updated_csv)) {
    printed_table <- paste(capture.output(print(table, row.names = FALSE)), collapse = "\n")
    stopifnot(grepl(printed_table, console_text, fixed = TRUE))
  }
  stopifnot(
    grepl("Q1(c): the original eight slots are insufficient.", console_text, fixed = TRUE),
    grepl(paste("The first valid timetable uses", validation_csv$initial_time_periods_required,
                "time periods over", max(initial_csv$day), "days."), console_text, fixed = TRUE),
    grepl(paste("Trying fewer days first gives", validation_csv$updated_days_required,
                "days for this updated timetable."), console_text, fixed = TRUE)
  )

  expect_error <- function(expression, wording) {
    error <- tryCatch({ force(expression); NULL }, error = function(e) e)
    stopifnot(inherits(error, "error"), grepl(wording, conditionMessage(error), fixed = TRUE))
  }

  # Different slot numbers in different venues can still be concurrent.
  pair <- data.frame(
    day = c(1L, 1L), slot = c(1L, 2L), period = c("Morning", "Morning"),
    venue = c("Venue 1", "Venue 2"), capacity = c(40L, 70L),
    course = c("CCS592", "CDS506"), students = c(38L, 38L)
  )
  pair_conflict <- conflict[pair$course, pair$course]
  expect_error(validate_q1_initial_timetable(pair, pair_conflict), "concurrent")

  # Same-day morning/afternoon is valid for (c), but forbidden for (d).
  pair$period[[2L]] <- "Afternoon"
  pair$slot[[2L]] <- 4L
  validate_q1_initial_timetable(pair, pair_conflict)
  expect_error(validate_q1_timetable(pair, pair_conflict), "same day")
  # The same student may sit exams on consecutive days.
  pair$day[[2L]] <- 2L
  pair$period[[2L]] <- "Morning"
  pair$slot[[2L]] <- 6L
  validate_q1_timetable(pair, pair_conflict)

  # Even courses with no common students cannot double-book a room.
  pair_conflict[1L, 2L] <- pair_conflict[2L, 1L] <- 0L
  pair$day[[2L]] <- 1L
  pair$slot[[2L]] <- 1L
  pair$venue[[2L]] <- "Venue 1"
  pair$capacity[[2L]] <- 40L
  expect_error(validate_q1_initial_timetable(pair, pair_conflict), "booked more than once")

  bad <- initial
  bad$capacity[[1L]] <- 999L
  expect_error(validate_q1_initial_timetable(bad, conflict), "actual enrolment or venue capacity")
  bad <- initial
  bad$students[[1L]] <- 1L
  expect_error(validate_q1_initial_timetable(bad, conflict), "actual enrolment or venue capacity")
  bad <- initial
  large_row <- match("CDS501", bad$course)
  bad$day[[large_row]] <- 6L
  bad$period[[large_row]] <- "Morning"
  bad$venue[[large_row]] <- "Venue 1"
  bad$capacity[[large_row]] <- 40L
  bad$slot[[large_row]] <- 21L
  expect_error(validate_q1_initial_timetable(bad, conflict), "actual enrolment or venue capacity")
  bad <- initial
  bad$slot[[1L]] <- 50L
  expect_error(validate_q1_initial_timetable(bad, conflict), "Slot numbers")
  expect_error(validate_q1_initial_timetable(initial[-1L, ], conflict), "exactly once")
  expect_error(validate_q1_initial_timetable(rbind(initial, initial[1L, ]), conflict), "exactly once")

  # No shared students: room capacities alone can make eight slots insufficient.
  large_courses <- setNames(lapply(seq_len(6L), function(i) {
    paste0("course", i, "_student", seq_len(41L))
  }), names(courses))
  large_conflict <- build_q1_conflict_matrix(large_courses)
  large_result <- generate_q1_timetable(large_courses, large_conflict)
  stopifnot(
    large_result$initial_minimum_sessions == 6L,
    !large_result$original_eight_slots_sufficient,
    large_result$minimum_days == 3L
  )
  check_schedule(large_result$initial_timetable, large_courses)
  check_schedule(large_result$timetable, large_courses, no_back_to_back = TRUE)

  # Six independent small exams fit in three periods, or two days for (d).
  small_courses <- lapply(large_courses, head, 40L)
  small_result <- generate_q1_timetable(small_courses, build_q1_conflict_matrix(small_courses))
  stopifnot(small_result$initial_minimum_sessions == 3L,
            small_result$original_eight_slots_sufficient,
            small_result$minimum_days == 2L)
  check_schedule(small_result$initial_timetable, small_courses)
  check_schedule(small_result$timetable, small_courses, no_back_to_back = TRUE)

  large_courses[[1L]] <- paste0("oversized", seq_len(71L))
  expect_error(generate_q1_timetable(large_courses, build_q1_conflict_matrix(large_courses)),
               "venue capacities")

  cat("ALL Q1 PIPELINE CHECKS PASSED.\n")
  invisible(TRUE)
}

if (sys.nframe() == 0L) test_q1_pipeline()
