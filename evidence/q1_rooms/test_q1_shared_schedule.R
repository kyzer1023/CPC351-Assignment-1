# Check room sharing and splitting against memberships and known lower bounds.

source("assignment_files/q1_clean.R")
source("assignment_files/q1_conflict.R")
source("assignment_files/q1_schedule.R")
source("assignment_files/q1_shared_schedule.R")
source("evidence/q1_rooms/q1_synthetic_cases.R")

test_q1_shared_schedule <- function() {
  expect_error <- function(expression, wording) {
    error <- tryCatch({ force(expression); NULL }, error = function(e) e)
    stopifnot(inherits(error, "error"), grepl(wording, conditionMessage(error), fixed = TRUE))
  }

  # Reconstruct seat use and student attendance independently of the validator.
  check_result <- function(result, courses) {
    for (part in c("c", "d")) {
      timetable <- if (part == "c") result$initial_timetable else result$timetable
      students <- if (part == "c") result$initial_allocation else result$updated_allocation
      stopifnot(nrow(students) == sum(lengths(courses)))
      for (course in names(courses)) {
        rows <- students[students$course == course, ]
        stopifnot(setequal(rows$student, courses[[course]]), !anyDuplicated(rows$student),
                  nrow(unique(rows[c("day", "period")])) == 1L)
      }
      for (slot in unique(students$slot)) {
        rows <- students[students$slot == slot, ]
        room <- unique(rows$venue)
        stopifnot(length(room) == 1L,
                  nrow(rows) <= if (room == "Venue 1") 40L else 70L,
                  nrow(rows) == sum(timetable$students[timetable$slot == slot]))
      }
      for (student in unique(students$student)) {
        exams <- students[students$student == student, ]
        stopifnot(!anyDuplicated(exams[c("day", "period")]))
        if (part == "d") stopifnot(!anyDuplicated(exams$day))
      }
    }
  }

  root <- q1_find_project_root()
  supplied <- clean_q1_registrations(read_q1_registration_lists(root))$courses
  conflict <- build_q1_conflict_matrix(supplied)
  shared <- generate_q1_shared_timetables(supplied, conflict)
  check_result(shared, supplied)
  stopifnot(shared$initial_minimum_sessions == 5L, shared$minimum_days == 5L,
            length(unique(shared$initial_timetable$slot)) == 5L,
            length(unique(shared$timetable$slot)) == 5L,
            nrow(shared$initial_timetable) == 6L, nrow(shared$timetable) == 6L)
  for (table in list(shared$initial_timetable, shared$timetable)) {
    pair <- table[table$course %in% c("CDS501", "CDS523"), ]
    stopifnot(length(unique(pair$slot)) == 1L, sum(pair$students) == 60L,
              all(pair$venue == "Venue 2"))
  }

  cases <- q1_synthetic_cases()
  small <- cases$small_independent
  medium <- cases$medium_independent
  for (courses in list(small, medium)) {
    matrix <- build_q1_conflict_matrix(courses)
    result <- generate_q1_shared_timetables(courses, matrix)
    sharing_only <- generate_q1_shared_timetables(courses, matrix, allow_splitting = FALSE)
    baseline <- generate_q1_timetable(courses, matrix)
    check_result(result, courses)
    check_result(sharing_only, courses)
    if (identical(courses, small)) {
      # 90 registrations need both rooms, but fit together in one period.
      stopifnot(baseline$initial_minimum_sessions == 3L, baseline$minimum_days == 2L,
                result$initial_minimum_sessions == 1L, result$minimum_days == 1L,
                sharing_only$initial_minimum_sessions == 1L,
                length(unique(result$initial_timetable$slot)) == 2L)
    } else {
      # Each pair totals 82 seats: splitting is necessary to fit three pairs.
      # Three courses total 123 > 110, proving at least three periods are needed.
      stopifnot(baseline$initial_minimum_sessions == 6L, baseline$minimum_days == 3L,
                sharing_only$initial_minimum_sessions == 6L, sharing_only$minimum_days == 3L,
                result$initial_minimum_sessions == 3L, result$minimum_days == 2L,
                anyDuplicated(result$initial_timetable$course) > 0L)
    }
  }

  oversized <- cases$oversized
  matrix <- build_q1_conflict_matrix(oversized)
  expect_error(generate_q1_timetable(oversized, matrix), "venue capacities")
  expect_error(generate_q1_shared_timetables(oversized, matrix, FALSE), "No shared-room")
  check_result(generate_q1_shared_timetables(oversized, matrix), oversized)
  too_large <- make_q1_independent_courses(c(111L, rep(10L, 5L)))
  expect_error(generate_q1_shared_timetables(too_large, build_q1_conflict_matrix(too_large)),
               "1 to 110")

  # Splitting must never bypass a clash, including one in a different room.
  all_conflict <- make_q1_independent_courses(rep(10L, 6L))
  all_conflict <- lapply(all_conflict, function(ids) c(ids, "COMMON_STUDENT"))
  result <- generate_q1_shared_timetables(all_conflict, build_q1_conflict_matrix(all_conflict))
  stopifnot(result$initial_minimum_sessions == 6L, result$minimum_days == 6L)
  check_result(result, all_conflict)

  # Input order must not change the result or mislabel room assignments.
  reordered <- generate_q1_shared_timetables(rev(supplied), conflict)
  stopifnot(identical(reordered, shared))

  # Compare the search with a separate exhaustive enumeration on a mixed case.
  # This reference checks every labelled period assignment, without pruning.
  mixed <- make_q1_independent_courses(c(55L, 35L, 25L, 41L, 15L, 20L))
  mixed[[1L]] <- c(mixed[[1L]], "SHARED_A")
  mixed[[2L]] <- c(mixed[[2L]], "SHARED_A")
  mixed[[3L]] <- c(mixed[[3L]], "SHARED_B")
  mixed[[4L]] <- c(mixed[[4L]], "SHARED_B")
  mixed_conflict <- build_q1_conflict_matrix(mixed)
  mixed_result <- generate_q1_shared_timetables(mixed, mixed_conflict)
  check_result(mixed_result, mixed)
  for (part in c("c", "d")) {
    found <- FALSE
    for (limit in 1:3) {
      period_count <- if (part == "c") limit else 2L * limit
      combinations <- expand.grid(rep(list(seq_len(period_count)), 6L))
      best_bookings <- Inf
      for (row in seq_len(nrow(combinations))) {
        periods <- as.integer(combinations[row, ])
        groups <- if (part == "c") periods else (periods + 1L) %/% 2L
        valid <- TRUE
        for (i in 2:6) {
          for (j in seq_len(i - 1L)) {
            if (groups[[i]] == groups[[j]] && mixed_conflict[i, j] > 0L) valid <- FALSE
          }
        }
        if (!valid) next
        totals <- tapply(lengths(mixed), periods, sum)
        if (any(totals > 110L)) next
        best_bookings <- min(best_bookings, sum(ifelse(totals <= 70L, 1L, 2L)))
      }
      if (is.finite(best_bookings)) {
        actual_limit <- if (part == "c") mixed_result$initial_minimum_sessions else mixed_result$minimum_days
        table <- if (part == "c") mixed_result$initial_timetable else mixed_result$timetable
        stopifnot(actual_limit == limit, length(unique(table$slot)) == best_bookings)
        found <- TRUE
        break
      }
    }
    stopifnot(found)
  }

  bad <- shared$initial_timetable
  bad$students[[1L]] <- 100L
  expect_error(validate_q1_shared_timetable(bad, shared$initial_allocation, supplied), "capacity")
  bad <- shared$initial_allocation[-1L, ]
  expect_error(validate_q1_shared_timetable(shared$initial_timetable, bad, supplied), "exactly once")
  bad <- rbind(shared$initial_allocation, shared$initial_allocation[1L, ])
  expect_error(validate_q1_shared_timetable(shared$initial_timetable, bad, supplied), "exactly once")
  bad <- shared$initial_allocation
  bad$venue[[1L]] <- "Venue 9"
  expect_error(validate_q1_shared_timetable(shared$initial_timetable, bad, supplied), "disagrees")
  bad <- shared$initial_timetable
  bad$slot[[1L]] <- 99L
  expect_error(validate_q1_shared_timetable(bad, shared$initial_allocation, supplied), "slot numbers")

  # A deliberately moved half of a split exam must be rejected.
  result <- generate_q1_shared_timetables(medium, build_q1_conflict_matrix(medium))
  row <- which(duplicated(result$initial_timetable$course))[[1L]]
  course <- result$initial_timetable$course[[row]]
  old_slot <- result$initial_timetable$slot[[row]]
  students <- result$initial_allocation
  moved <- students$course == course & students$slot == old_slot
  result$initial_timetable$day[[row]] <- 10L
  result$initial_timetable$slot[[row]] <- old_slot + 36L
  students$day[moved] <- 10L
  students$slot[moved] <- old_slot + 36L
  expect_error(validate_q1_shared_timetable(result$initial_timetable, students, medium), "one period")

  cat("ALL Q1 SHARED-ROOM CHECKS PASSED.\n")
}

if (sys.nframe() == 0L) test_q1_shared_schedule()
