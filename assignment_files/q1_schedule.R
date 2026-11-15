# Q1(c): avoid shared-student exams in the same morning or afternoon.
# Q1(d): also avoid shared-student exams on the same day.
# Each course stays together in one room; each room holds one course per period.
# Venue 1 has 40 seats and Venue 2 has 70 seats.
#
# Terminology used below:
#   A period is one morning or afternoon, across both venues.
#   A slot is one room in one period. Each day therefore has four slots:
#     Morning: Venue 1 = slot 1, Venue 2 = slot 2.
#     Afternoon: Venue 1 = slot 3, Venue 2 = slot 4.
#   Slot numbers continue on later days: Day 2 starts at slot 5.
#
# Both searches use backtracking: try a placement, finish the remaining courses,
# and try another placement if that branch fails. They return the first solution
# at the smallest feasible limit. Room placement and validation follow below.

# Q1(c): assign periods, choose venues, and validate the timetable. ----

find_q1_period_assignment <- function(conflict_matrix, course_sizes) {
  course_names <- rownames(conflict_matrix)
  course_sizes <- course_sizes[course_names]
  n_courses <- length(course_names)

  try_period_limit <- function(period_limit) {
    # One entry per course: c(1, 0, 2) means Period 1, unassigned, Period 2.
    # Return the completed assignment on success, or NULL if this branch fails.
    search <- function(course_index, assigned_period) {
      if (course_index > n_courses) return(assigned_period)
      size <- course_sizes[[course_index]]
      used_periods <- max(assigned_period)
      # Try existing periods plus the next unused one. Skipping an empty period
      # would only repeat the same timetable with different period numbers.
      last_period <- min(period_limit, used_periods + 1L)

      # Try each candidate period for this course, skipping clashes or full rooms.
      for (period_index in seq_len(last_period)) {
        same_period <- which(assigned_period == period_index)
        # Two rooms can hold at most two courses, and only Venue 2 fits over 40.
        if (length(same_period) >= 2L || size > 70L) next
        if (size > 40L && any(course_sizes[same_period] > 40L)) next
        if (any(conflict_matrix[course_index, same_period] > 0L)) next

        # Tentatively place this course, then try to place all remaining courses.
        assigned_period[[course_index]] <- period_index
        solution <- search(course_index + 1L, assigned_period)
        if (!is.null(solution)) return(solution)

        # A later course could not fit. Clear this choice and try another period.
        # The recursive call's other changes stay in its own assignment vector.
        assigned_period[[course_index]] <- 0L
      }
      NULL
    }

    search(1L, integer(n_courses))
  }

  # Try one period, then two, and so on. The first successful limit is the minimum.
  for (period_limit in seq_len(n_courses)) {
    assignment <- try_period_limit(period_limit)
    if (!is.null(assignment)) {
      return(list(period = assignment, minimum_periods = max(assignment)))
    }
  }
  stop("No non-concurrent timetable found within the venue capacities.", call. = FALSE)
}

build_q1_period_timetable <- function(courses, conflict_matrix) {
  course_names <- rownames(conflict_matrix)
  course_sizes <- lengths(courses)[course_names]
  venue_capacities <- c(40L, 70L)
  period_result <- find_q1_period_assignment(conflict_matrix, course_sizes)
  period_assignment <- period_result$period
  rows <- vector("list", length(course_names))

  # Turn each assigned period into room bookings on a numbered day.
  for (period_index in seq_len(period_result$minimum_periods)) {
    members <- which(period_assignment == period_index)
    if (length(members) == 0L) next
    member_order <- members[order(course_sizes[members])]
    venue_used <- integer(0)
    # Seat smaller exams first in Venue 1, leaving Venue 2 available for larger ones.
    for (course_index in member_order) {
      allowed <- if (course_sizes[[course_index]] <= venue_capacities[[1L]]) {
        c(1L, 2L)
      } else {
        2L
      }
      venue <- allowed[!allowed %in% venue_used][[1L]]
      venue_used <- c(venue_used, venue)
      # Integer division groups periods 1/2 into Day 1, 3/4 into Day 2, etc.
      # Odd periods are mornings; even periods are afternoons.
      day <- (period_index + 1L) %/% 2L
      period <- if (period_index %% 2L == 1L) "Morning" else "Afternoon"
      local_slot <- if (period == "Morning") venue else 2L + venue
      rows[[course_index]] <- data.frame(
        day = day,
        slot = (day - 1L) * 4L + local_slot,
        period = period,
        venue = paste("Venue", venue),
        capacity = venue_capacities[[venue]],
        course = course_names[[course_index]],
        students = course_sizes[[course_index]],
        stringsAsFactors = FALSE
      )
    }
  }
  timetable <- do.call(rbind, rows)
  timetable <- timetable[order(timetable$day,
                               match(timetable$period, c("Morning", "Afternoon")),
                               match(timetable$venue, c("Venue 1", "Venue 2"))), ]
  rownames(timetable) <- NULL
  list(timetable = timetable,
       minimum_periods = period_result$minimum_periods)
}

validate_q1_period_timetable <- function(timetable, conflict_matrix) {
  # Check that each course appears once and that all booking labels are valid.
  if (anyDuplicated(timetable$course) > 0L ||
      !setequal(timetable$course, rownames(conflict_matrix))) {
    stop("Timetable must schedule each course exactly once.", call. = FALSE)
  }
  if (any(!is.finite(timetable$day) | timetable$day < 1L |
          timetable$day != floor(timetable$day)) ||
      any(!timetable$period %in% c("Morning", "Afternoon")) ||
      any(!timetable$venue %in% c("Venue 1", "Venue 2"))) {
    stop("Timetable has an invalid day, period or venue.", call. = FALSE)
  }

  # Check the displayed values against the assignment, not just against each other.
  venue_number <- match(timetable$venue, c("Venue 1", "Venue 2"))
  actual_capacity <- c(40L, 70L)[venue_number]
  actual_students <- diag(conflict_matrix)[timetable$course]
  expected_slot <- (timetable$day - 1L) * 4L + venue_number +
    ifelse(timetable$period == "Afternoon", 2L, 0L)
  if (any(timetable$capacity != actual_capacity) ||
      any(timetable$students != actual_students) ||
      any(actual_students > actual_capacity)) {
    stop("Timetable violates the actual enrolment or venue capacity.", call. = FALSE)
  }
  if (any(timetable$slot != expected_slot)) {
    stop("Slot numbers do not match the day, period and venue.", call. = FALSE)
  }
  if (anyDuplicated(timetable$slot) > 0L) {
    stop("A room/time slot was booked more than once.", call. = FALSE)
  }

  # Check each exam against the earlier exams for simultaneous student clashes.
  for (i in seq_len(nrow(timetable))) {
    # Earlier rows only: each pair is checked once, with no self-comparison.
    for (j in seq_len(i - 1L)) {
      if (timetable$day[[i]] == timetable$day[[j]] &&
          timetable$period[[i]] == timetable$period[[j]] &&
          conflict_matrix[timetable$course[[i]], timetable$course[[j]]] > 0L) {
        stop("Timetable has a concurrent examination conflict.", call. = FALSE)
      }
    }
  }
  invisible(TRUE)
}

# Q1(d): assign days, choose room/time slots, and validate the timetable. ----

find_q1_day_assignment <- function(conflict_matrix, course_sizes) {
  course_names <- rownames(conflict_matrix)
  course_sizes <- course_sizes[course_names]
  n_courses <- length(course_names)

  try_day_limit <- function(day_limit) {
    # One entry per course: c(1, 0, 2) means Day 1, unassigned, Day 2.
    # A completed assignment is returned on success; NULL means this branch failed.
    search <- function(course_index, assigned_day) {
      if (course_index > n_courses) return(assigned_day)
      size <- course_sizes[[course_index]]
      used_days <- max(assigned_day)
      # Existing days plus the next unused day are enough. Skipping an empty day
      # would only produce the same timetable with different day numbers.
      last_day <- min(day_limit, used_days + 1L)

      # Try each candidate day; a student conflict excludes the whole day.
      for (day in seq_len(last_day)) {
        same_day <- which(assigned_day == day)
        # Four room/time slots per day, but only two can hold over 40 students.
        if (length(same_day) >= 4L || size > 70L) next
        if (size > 40L && sum(course_sizes[same_day] > 40L) >= 2L) next
        # In (d), a shared student rules out the whole day, including afternoon.
        if (any(conflict_matrix[course_index, same_day] > 0L)) next

        # Tentatively place this course, then try to place all remaining courses.
        assigned_day[[course_index]] <- day
        solution <- search(course_index + 1L, assigned_day)
        if (!is.null(solution)) return(solution)

        # Each recursive call receives its own vector. Clear this course here
        # before trying its next day; failed calls leave no other changes behind.
        assigned_day[[course_index]] <- 0L
      }
      NULL
    }

    search(1L, integer(n_courses))
  }

  # Trying smaller day limits first makes the first solution a minimum.
  for (day_limit in seq_len(n_courses)) {
    assignment <- try_day_limit(day_limit)
    if (!is.null(assignment)) {
      return(list(day = assignment, minimum_days = max(assignment)))
    }
  }
  stop("No timetable found within the available room and daily-slot constraints.",
       call. = FALSE)
}

build_q1_day_timetable <- function(courses, day_assignment) {
  course_names <- names(courses)
  course_sizes <- lengths(courses)
  if (any(course_sizes > 70L)) {
    stop("At least one course exceeds the largest venue capacity (70).", call. = FALSE)
  }

  slot_table <- data.frame(
    local_slot = 1:4,
    period = c("Morning", "Morning", "Afternoon", "Afternoon"),
    venue = c("Venue 1", "Venue 2", "Venue 1", "Venue 2"),
    capacity = c(40L, 70L, 40L, 70L),
    stringsAsFactors = FALSE
  )
  rows <- vector("list", length(course_names))

  # Fill each assigned day's four room/time slots with its scheduled courses.
  for (day in seq_len(max(day_assignment))) {
    day_courses <- which(day_assignment == day)
    # The day search already checked student conflicts and room availability.
    # Assign rooms now, giving the courses that need Venue 2 first choice.
    course_order <- day_courses[order(-course_sizes[day_courses], course_names[day_courses])]
    occupied <- logical(nrow(slot_table))
    # Give larger exams first choice; reserve small-room slots for exams that fit.
    for (course_index in course_order) {
      preferred_slots <- if (course_sizes[[course_index]] <= 40L) {
        c(1L, 3L, 2L, 4L)
      } else {
        c(2L, 4L)
      }
      available <- preferred_slots[!occupied[preferred_slots]]
      if (length(available) == 0L) {
        stop("Unable to place all courses into the available venues and periods.",
             call. = FALSE)
      }
      slot <- available[[1L]]
      occupied[[slot]] <- TRUE
      rows[[course_index]] <- data.frame(
        day = day,
        slot = (day - 1L) * 4L + slot,
        period = slot_table$period[[slot]],
        venue = slot_table$venue[[slot]],
        capacity = slot_table$capacity[[slot]],
        course = course_names[[course_index]],
        students = course_sizes[[course_index]],
        stringsAsFactors = FALSE
      )
    }
  }

  result <- do.call(rbind, rows)
  result <- result[order(result$day, match(result$period, c("Morning", "Afternoon")),
                         match(result$venue, c("Venue 1", "Venue 2"))), ]
  rownames(result) <- NULL
  result
}

validate_q1_day_timetable <- function(timetable, conflict_matrix) {
  # Q1(d) keeps all Q1(c) checks, then adds the restriction on same-day exams.
  validate_q1_period_timetable(timetable, conflict_matrix)
  # Check each exam against earlier exams, including those in a different period.
  for (i in seq_len(nrow(timetable))) {
    # Earlier rows only: each pair is checked once, with no self-comparison.
    for (j in seq_len(i - 1L)) {
      course_a <- timetable$course[[i]]
      course_b <- timetable$course[[j]]
      if (timetable$day[[i]] == timetable$day[[j]] &&
          conflict_matrix[course_a, course_b] > 0L) {
        stop("Timetable places shared students in exams on the same day.",
             call. = FALSE)
      }
    }
  }
  invisible(TRUE)
}

# Run both scheduling steps, display their results, and export them. ----

generate_q1_timetables <- function(courses, conflict_matrix) {
  # Keep course positions aligned with the conflict matrix throughout the search.
  courses <- courses[rownames(conflict_matrix)]

  # Q1(c): minimize periods, then map each period to a day and two venues.
  period_result <- build_q1_period_timetable(courses, conflict_matrix)
  validate_q1_period_timetable(period_result$timetable, conflict_matrix)

  # Q1(d): minimize days first, then choose room/time slots within each day.
  day_assignment <- find_q1_day_assignment(conflict_matrix, lengths(courses))
  day_timetable <- build_q1_day_timetable(courses, day_assignment$day)
  validate_q1_day_timetable(day_timetable, conflict_matrix)

  # The original eight room/time slots cover only four periods over two days.
  list(period_timetable = period_result$timetable,
       minimum_periods = period_result$minimum_periods,
       day_timetable = day_timetable,
       minimum_days = day_assignment$minimum_days,
       original_eight_slots_sufficient = period_result$minimum_periods <= 4L)
}

print_q1_timetable <- function(timetable) {
  periods <- unique(timetable[c("day", "period")])
  periods <- periods[order(periods$day, match(periods$period, c("Morning", "Afternoon"))), ]
  display <- data.frame(Day = periods$day, Period = periods$period,
                        venue_1 = "-", venue_2 = "-", stringsAsFactors = FALSE)
  names(display) <- c("Day", "Period", "Venue 1 (40 seats)", "Venue 2 (70 seats)")

  # Copy each booking into its day/period row and venue column.
  for (i in seq_len(nrow(timetable))) {
    period_row <- which(periods$day == timetable$day[[i]] &
                          periods$period == timetable$period[[i]])
    venue_column <- match(timetable$venue[[i]], c("Venue 1", "Venue 2")) + 2L
    display[period_row, venue_column] <- sprintf("%s (%d), slot %d",
      timetable$course[[i]], timetable$students[[i]], timetable$slot[[i]])
  }
  row_format <- "%-3s  %-9s  %-25s  %s\n"
  cat(sprintf(row_format, names(display)[[1L]], names(display)[[2L]],
              names(display)[[3L]], names(display)[[4L]]))
  # Print one row per occupied period, with both venues shown side by side.
  for (i in seq_len(nrow(display))) {
    cat(sprintf(row_format, as.character(display$Day[[i]]), display$Period[[i]],
                display[[3L]][[i]], display[[4L]][[i]]))
  }
  invisible(NULL)
}

print_q1_timetables <- function(schedule_result) {
  cat("\nQ1(c): No concurrent exams for shared students\n")
  cat("Restriction: Courses sharing students must use different periods.\n")
  cat("Rooms: One course per room, within its seating capacity.\n")
  cat("\nResult:", nrow(schedule_result$period_timetable), "courses |",
      schedule_result$minimum_periods, "periods |",
      max(schedule_result$period_timetable$day), "days\n")
  cat("Original 2-day limit:",
      if (schedule_result$original_eight_slots_sufficient) "sufficient\n\n" else "insufficient\n\n")
  print_q1_timetable(schedule_result$period_timetable)

  cat("\nQ1(d): No back-to-back exams for shared students\n")
  cat("Restriction: Courses sharing students must use different days.\n")
  cat("Consecutive days are allowed.\n")
  cat("Rooms: One course per room, within its seating capacity.\n")
  cat("\nResult:", nrow(schedule_result$day_timetable), "courses |",
      schedule_result$minimum_days, "days\n\n")
  print_q1_timetable(schedule_result$day_timetable)
  invisible(NULL)
}

write_q1_timetable_outputs <- function(schedule_result, project_root) {
  output_dir <- file.path(project_root, "outputs", "q1")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(schedule_result$period_timetable,
                   file.path(output_dir, "concurrent_conflict_timetable.csv"),
                   row.names = FALSE)
  utils::write.csv(schedule_result$day_timetable,
                   file.path(output_dir, "examination_timetable.csv"),
                   row.names = FALSE)
  # Both timetables passed the validators before reaching this export.
  # Keep the existing CSV column names so reports can use the same format.
  validation <- data.frame(
    courses_scheduled = nrow(schedule_result$period_timetable),
    initial_time_periods_required = schedule_result$minimum_periods,
    original_eight_slots_sufficient = schedule_result$original_eight_slots_sufficient,
    updated_days_required = schedule_result$minimum_days,
    back_to_back_conflicts = 0L,
    capacity_violations = 0L,
    stringsAsFactors = FALSE
  )
  utils::write.csv(validation,
                   file.path(output_dir, "timetable_validation.csv"),
                   row.names = FALSE)
  invisible(validation)
}

# Standalone entry point: running this file uses the previously cleaned lists.
if (sys.nframe() == 0L) {
  if (!exists("find_q1_project_root", mode = "function")) {
    source(file.path("assignment_files", "q1_clean.R"), local = TRUE)
  }
  source(file.path("assignment_files", "q1_conflict.R"), local = TRUE)
  root <- find_q1_project_root()
  clean_path <- file.path(root, "outputs", "q1", "courses_clean.rds")
  if (!file.exists(clean_path)) {
    stop("Run assignment_files/q1_clean.R first to create the cleaned registration lists.",
         call. = FALSE)
  }
  courses <- readRDS(clean_path)
  conflict_matrix <- build_q1_conflict_matrix(courses)
  result <- generate_q1_timetables(courses, conflict_matrix)
  write_q1_timetable_outputs(result, root)
  print_q1_timetables(result)
}
