# Q1 integration checks for cleaning, conflict counts, and both timetables.

test_q1_pipeline <- function() {
  script_dir <- normalizePath("assignment_files", winslash = "/", mustWork = TRUE)
  source(file.path(script_dir, "q1_clean.R"), local = TRUE)
  source(file.path(script_dir, "q1_conflict.R"), local = TRUE)
  source(file.path(script_dir, "q1_schedule.R"), local = TRUE)
  source(file.path(script_dir, "q1_main.R"), local = TRUE)

  root <- find_q1_project_root()
  console <- capture.output(result <- suppressMessages(run_q1_pipeline(root)))
  courses <- result$cleaning$courses
  conflict <- result$conflict_matrix
  period_timetable <- result$schedule$period_timetable
  day_timetable <- result$schedule$day_timetable

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
    identical(result$schedule$minimum_periods, 5L),
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

  check_schedule(period_timetable, courses)
  check_schedule(day_timetable, courses, no_back_to_back = TRUE)
  stopifnot(
    length(unique(paste(period_timetable$day, period_timetable$period))) == 5L,
    length(unique(day_timetable$day)) == 5L,
    max(period_timetable$day) == 3L,
    any(period_timetable$slot > 8L)
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

  period_csv <- read.csv(file.path(root, "outputs/q1/concurrent_conflict_timetable.csv"))
  day_csv <- read.csv(file.path(root, "outputs/q1/examination_timetable.csv"))
  validation_csv <- read.csv(file.path(root, "outputs/q1/timetable_validation.csv"))
  stopifnot(
    identical(period_csv, period_timetable),
    identical(day_csv, day_timetable),
    identical(validation_csv, result$validation),
    validation_csv$courses_scheduled == nrow(period_csv),
    validation_csv$initial_time_periods_required == nrow(unique(period_csv[c("day", "period")])),
    validation_csv$updated_days_required == length(unique(day_csv$day)),
    !validation_csv$original_eight_slots_sufficient,
    validation_csv$back_to_back_conflicts == 0L,
    validation_csv$capacity_violations == 0L
  )
  # Each displayed period must match the bookings in the exported timetable.
  console_text <- paste(console, collapse = "\n")
  section_starts <- grep("^Q1\\([cd]\\): (No concurrent|No back-to-back)", console)
  stopifnot(length(section_starts) == 2L)
  tables <- list(period_csv, day_csv)
  # Compare each part's printed table with the corresponding exported timetable.
  for (part in 1:2) {
    section_end <- if (part == 1L) section_starts[[2L]] - 1L else length(console)
    section <- console[seq.int(section_starts[[part]], section_end)]
    displayed_rows <- section[grepl("^\\s*[0-9]+\\s+(Morning|Afternoon)\\s+", section)]
    table <- tables[[part]]
    periods <- unique(table[c("day", "period")])
    stopifnot(length(displayed_rows) == nrow(periods),
              any(grepl("Venue 1 (40 seats)", section, fixed = TRUE)),
              any(grepl("Venue 2 (70 seats)", section, fixed = TRUE)))

    # Recreate the expected display for each occupied period.
    for (i in seq_len(nrow(periods))) {
      bookings <- table[table$day == periods$day[[i]] &
                          table$period == periods$period[[i]], ]
      cells <- c("-", "-")
      # Fill both venue cells, leaving a dash when that room is unused.
      for (room in 1:2) {
        exam <- bookings[bookings$venue == paste("Venue", room), ]
        if (nrow(exam) == 1L) {
          cells[[room]] <- paste0(exam$course, " (", exam$students, "), slot ", exam$slot)
        }
      }
      expected_row <- paste(periods$day[[i]], periods$period[[i]], cells[[1L]], cells[[2L]])
      actual_row <- trimws(gsub("[[:space:]]+", " ", displayed_rows[[i]]))
      stopifnot(identical(actual_row, expected_row))
    }
  }
  stopifnot(
    grepl("Restriction: Courses sharing students must use different periods.", console_text, fixed = TRUE),
    grepl("Restriction: Courses sharing students must use different days.", console_text, fixed = TRUE),
    grepl("Consecutive days are allowed.", console_text, fixed = TRUE),
    grepl("Original 2-day limit: insufficient", console_text, fixed = TRUE),
    grepl(paste("Result:", nrow(period_csv), "courses |", validation_csv$initial_time_periods_required,
                "periods |", max(period_csv$day), "days"), console_text, fixed = TRUE),
    grepl(paste("Result:", nrow(day_csv), "courses |", validation_csv$updated_days_required,
                "days"), console_text, fixed = TRUE),
    !grepl("Checks:|Concurrent clashes:|Capacity violations:|The search tries|Slot numbering continues",
           paste(console[seq.int(section_starts[[1L]], length(console))], collapse = "\n"))
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
  expect_error(validate_q1_period_timetable(pair, pair_conflict), "concurrent")

  # Same-day morning/afternoon is valid for (c), but forbidden for (d).
  pair$period[[2L]] <- "Afternoon"
  pair$slot[[2L]] <- 4L
  validate_q1_period_timetable(pair, pair_conflict)
  expect_error(validate_q1_day_timetable(pair, pair_conflict), "same day")
  # The same student may sit exams on consecutive days.
  pair$day[[2L]] <- 2L
  pair$period[[2L]] <- "Morning"
  pair$slot[[2L]] <- 6L
  validate_q1_day_timetable(pair, pair_conflict)

  # Even courses with no common students cannot double-book a room.
  pair_conflict[1L, 2L] <- pair_conflict[2L, 1L] <- 0L
  pair$day[[2L]] <- 1L
  pair$slot[[2L]] <- 1L
  pair$venue[[2L]] <- "Venue 1"
  pair$capacity[[2L]] <- 40L
  expect_error(validate_q1_period_timetable(pair, pair_conflict), "booked more than once")

  bad <- period_timetable
  bad$capacity[[1L]] <- 999L
  expect_error(validate_q1_period_timetable(bad, conflict), "actual enrolment or venue capacity")
  bad <- period_timetable
  bad$students[[1L]] <- 1L
  expect_error(validate_q1_period_timetable(bad, conflict), "actual enrolment or venue capacity")
  bad <- period_timetable
  large_row <- match("CDS501", bad$course)
  bad$day[[large_row]] <- 6L
  bad$period[[large_row]] <- "Morning"
  bad$venue[[large_row]] <- "Venue 1"
  bad$capacity[[large_row]] <- 40L
  bad$slot[[large_row]] <- 21L
  expect_error(validate_q1_period_timetable(bad, conflict), "actual enrolment or venue capacity")
  bad <- period_timetable
  bad$slot[[1L]] <- 50L
  expect_error(validate_q1_period_timetable(bad, conflict), "Slot numbers")
  expect_error(validate_q1_period_timetable(period_timetable[-1L, ], conflict), "exactly once")
  expect_error(validate_q1_period_timetable(rbind(period_timetable, period_timetable[1L, ]), conflict), "exactly once")

  # No shared students: room capacities alone can make eight slots insufficient.
  large_courses <- setNames(lapply(seq_len(6L), function(i) {
    paste0("course", i, "_student", seq_len(41L))
  }), names(courses))
  large_conflict <- build_q1_conflict_matrix(large_courses)
  large_result <- generate_q1_timetables(large_courses, large_conflict)
  stopifnot(
    large_result$minimum_periods == 6L,
    !large_result$original_eight_slots_sufficient,
    large_result$minimum_days == 3L
  )
  check_schedule(large_result$period_timetable, large_courses)
  check_schedule(large_result$day_timetable, large_courses, no_back_to_back = TRUE)

  # Six independent small exams fit in three periods, or two days for (d).
  small_courses <- lapply(large_courses, head, 40L)
  small_result <- generate_q1_timetables(small_courses, build_q1_conflict_matrix(small_courses))
  stopifnot(small_result$minimum_periods == 3L,
            small_result$original_eight_slots_sufficient,
            small_result$minimum_days == 2L)
  check_schedule(small_result$period_timetable, small_courses)
  check_schedule(small_result$day_timetable, small_courses, no_back_to_back = TRUE)

  large_courses[[1L]] <- paste0("oversized", seq_len(71L))
  expect_error(generate_q1_timetables(large_courses, build_q1_conflict_matrix(large_courses)),
               "venue capacities")

  cat("ALL Q1 PIPELINE CHECKS PASSED.\n")
  invisible(TRUE)
}

if (sys.nframe() == 0L) test_q1_pipeline()
