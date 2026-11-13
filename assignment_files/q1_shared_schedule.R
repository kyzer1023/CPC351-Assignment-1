# Optional Q1(c-d) extension: compatible courses may share rooms.
# A split exam still takes place in one period, with each student in one room.

pack_q1_shared_period <- function(course_sizes, allow_splitting = TRUE) {
  capacities <- c(40L, 70L)
  total <- sum(course_sizes)
  if (total > sum(capacities)) return(NULL)
  allocation <- matrix(0L, nrow = length(course_sizes), ncol = 2L)

  # Use one room when possible. This also avoids unnecessary splitting.
  if (total <= 70L) {
    room <- if (total <= 40L) 1L else 2L
    allocation[, room] <- course_sizes
    return(allocation)
  }

  # First try keeping every course together in one of the two rooms.
  remaining <- capacities
  place_whole_course <- function(position) {
    if (position > length(course_sizes)) return(TRUE)
    size <- course_sizes[[position]]
    for (room in 1:2) {
      if (size > remaining[[room]]) next
      allocation[position, room] <<- size
      remaining[[room]] <<- remaining[[room]] - size
      if (place_whole_course(position + 1L)) return(TRUE)
      remaining[[room]] <<- remaining[[room]] + size
      allocation[position, room] <<- 0L
    }
    FALSE
  }
  if (place_whole_course(1L)) return(allocation)
  if (!allow_splitting) return(NULL)

  # With splitting, any total up to 110 fits. Fill Venue 1, then Venue 2.
  # Only the course at the boundary needs to be divided.
  remaining_small_room <- 40L
  for (i in seq_along(course_sizes)) {
    allocation[i, 1L] <- min(course_sizes[[i]], remaining_small_room)
    allocation[i, 2L] <- course_sizes[[i]] - allocation[i, 1L]
    remaining_small_room <- remaining_small_room - allocation[i, 1L]
  }
  allocation
}

find_q1_shared_periods <- function(courses, conflict_matrix,
                                   no_back_to_back = FALSE, allow_splitting = TRUE) {
  course_names <- rownames(conflict_matrix)
  sizes <- lengths(courses)[course_names]
  if (any(sizes < 1L) || any(sizes > 110L)) {
    stop("Each course needs 1 to 110 students for the shared-room model.", call. = FALSE)
  }
  n_courses <- length(sizes)

  # For (c), try fewer periods first. For (d), try fewer days first.
  for (limit in seq_len(n_courses)) {
    period_limit <- if (no_back_to_back) 2L * limit else limit
    if (sum(sizes) > 110L * period_limit) next
    assigned_period <- integer(n_courses)
    best_assignment <- NULL
    best_bookings <- Inf

    search <- function(position) {
      # A room booking means one occupied venue in one period.
      bookings <- 0L
      for (period in unique(assigned_period[assigned_period > 0L])) {
        total <- sum(sizes[assigned_period == period])
        bookings <- bookings + if (total <= 70L) 1L else 2L
      }
      if (bookings >= best_bookings) return(invisible(NULL))
      if (position > n_courses) {
        best_assignment <<- assigned_period
        best_bookings <<- bookings
        return(invisible(NULL))
      }

      used_days <- max((assigned_period + 1L) %/% 2L)
      last_period <- if (no_back_to_back) {
        2L * min(limit, used_days + 1L)
      } else {
        min(limit, max(assigned_period) + 1L)
      }
      for (period in seq_len(last_period)) {
        day <- (period + 1L) %/% 2L
        # In (d), morning and afternoon are interchangeable within a day.
        if (no_back_to_back && period %% 2L == 0L &&
            !any(assigned_period == period - 1L)) next
        other_courses <- if (no_back_to_back) {
          which(assigned_period > 0L & (assigned_period + 1L) %/% 2L == day)
        } else {
          which(assigned_period == period)
        }
        if (any(conflict_matrix[position, other_courses] > 0L)) next
        members <- c(which(assigned_period == period), position)
        if (is.null(pack_q1_shared_period(sizes[members], allow_splitting))) next
        assigned_period[[position]] <<- period
        search(position + 1L)
        assigned_period[[position]] <<- 0L
      }
      invisible(NULL)
    }

    search(1L)
    if (!is.null(best_assignment)) return(best_assignment)
  }
  stop("No shared-room timetable fits these course sizes.", call. = FALSE)
}

build_q1_shared_timetable <- function(courses, assigned_period, allow_splitting = TRUE) {
  timetable_rows <- list()
  student_rows <- list()
  for (period in sort(unique(assigned_period))) {
    members <- which(assigned_period == period)
    allocation <- pack_q1_shared_period(lengths(courses)[members], allow_splitting)
    day <- (period + 1L) %/% 2L
    period_name <- if (period %% 2L == 1L) "Morning" else "Afternoon"
    for (i in seq_along(members)) {
      course <- names(courses)[members[[i]]]
      students <- sort(courses[[course]])
      first_student <- 1L
      for (room in 1:2) {
        count <- allocation[i, room]
        if (count == 0L) next
        slot <- (period - 1L) * 2L + room
        timetable_rows[[length(timetable_rows) + 1L]] <- data.frame(
          day = day, slot = slot, period = period_name, venue = paste("Venue", room),
          capacity = c(40L, 70L)[[room]], course = course, students = count
        )
        student_rows[[length(student_rows) + 1L]] <- data.frame(
          course = course, student = students[seq.int(first_student, length.out = count)],
          day = day, period = period_name, venue = paste("Venue", room), slot = slot
        )
        first_student <- first_student + count
      }
    }
  }
  list(timetable = do.call(rbind, timetable_rows),
       student_allocation = do.call(rbind, student_rows))
}

validate_q1_shared_timetable <- function(timetable, student_allocation, courses,
                                        no_back_to_back = FALSE) {
  fail <- function(message) stop(message, call. = FALSE)
  if (!setequal(timetable$course, names(courses)) ||
      anyDuplicated(timetable[c("course", "slot")])) {
    fail("Shared timetable must cover each course without repeated room rows.")
  }
  room <- match(timetable$venue, c("Venue 1", "Venue 2"))
  if (anyNA(room) || anyNA(timetable) ||
      any(!timetable$period %in% c("Morning", "Afternoon")) ||
      any(!is.finite(timetable$day) | timetable$day < 1L |
          timetable$day != floor(timetable$day)) ||
      any(!is.finite(timetable$students) | timetable$students < 1L |
          timetable$students != floor(timetable$students))) {
    fail("Shared timetable has an invalid room, day, period or student count.")
  }
  expected_slot <- (timetable$day - 1L) * 4L + room +
    ifelse(timetable$period == "Afternoon", 2L, 0L)
  if (any(timetable$slot != expected_slot) ||
      any(timetable$capacity != c(40L, 70L)[room])) {
    fail("Shared timetable has incorrect slot numbers or room capacities.")
  }
  for (slot in unique(timetable$slot)) {
    rows <- timetable[timetable$slot == slot, ]
    if (sum(rows$students) > rows$capacity[[1L]]) fail("Shared room exceeds capacity.")
  }
  expected <- do.call(rbind, lapply(names(courses), function(course) {
    data.frame(course = course, student = courses[[course]])
  }))
  actual_keys <- paste(student_allocation$course, student_allocation$student)
  if (anyNA(student_allocation) || anyDuplicated(actual_keys) ||
      !setequal(actual_keys, paste(expected$course, expected$student))) {
    fail("Student allocation must include each registration exactly once.")
  }
  room_keys <- paste(timetable$course, timetable$slot)
  allocation_keys <- paste(student_allocation$course, student_allocation$slot)
  matched_rows <- match(allocation_keys, room_keys)
  if (anyNA(matched_rows) ||
      any(tabulate(matched_rows, nrow(timetable)) != timetable$students) ||
      any(student_allocation$day != timetable$day[matched_rows]) ||
      any(student_allocation$period != timetable$period[matched_rows]) ||
      any(student_allocation$venue != timetable$venue[matched_rows])) {
    fail("Student allocation disagrees with the room timetable.")
  }
  for (course in names(courses)) {
    rows <- timetable[timetable$course == course, ]
    if (nrow(unique(rows[c("day", "period")])) != 1L) {
      fail("A split course must sit its exam in one period.")
    }
  }
  for (student in unique(student_allocation$student)) {
    exams <- student_allocation[student_allocation$student == student, ]
    if (anyDuplicated(exams[c("day", "period")])) fail("Student has concurrent exams.")
    if (no_back_to_back && anyDuplicated(exams$day)) fail("Student has same-day exams.")
  }
  invisible(TRUE)
}

generate_q1_shared_timetables <- function(courses, conflict_matrix, allow_splitting = TRUE) {
  courses <- courses[rownames(conflict_matrix)]
  initial_periods <- find_q1_shared_periods(courses, conflict_matrix,
                                           allow_splitting = allow_splitting)
  updated_periods <- find_q1_shared_periods(courses, conflict_matrix,
                                           no_back_to_back = TRUE,
                                           allow_splitting = allow_splitting)
  initial <- build_q1_shared_timetable(courses, initial_periods, allow_splitting)
  updated <- build_q1_shared_timetable(courses, updated_periods, allow_splitting)
  validate_q1_shared_timetable(initial$timetable, initial$student_allocation, courses)
  validate_q1_shared_timetable(updated$timetable, updated$student_allocation, courses, TRUE)
  list(initial_timetable = initial$timetable, timetable = updated$timetable,
       initial_allocation = initial$student_allocation,
       updated_allocation = updated$student_allocation,
       initial_minimum_sessions = max(initial_periods),
       minimum_days = max((updated_periods + 1L) %/% 2L),
       original_eight_slots_sufficient = max(initial_periods) <= 4L)
}

write_q1_shared_outputs <- function(result, project_root) {
  output_dir <- file.path(project_root, "outputs", "q1", "shared_rooms")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  tables <- list(concurrent_conflict_timetable = result$initial_timetable,
                 examination_timetable = result$timetable,
                 initial_student_rooms = result$initial_allocation,
                 updated_student_rooms = result$updated_allocation)
  for (name in names(tables)) {
    write.csv(tables[[name]], file.path(output_dir, paste0(name, ".csv")), row.names = FALSE)
  }
  invisible(result)
}
