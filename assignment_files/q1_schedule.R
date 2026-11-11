# Q1(c): avoid shared-student exams in the same morning or afternoon.
# Q1(d): also avoid shared-student exams on the same day.
# Each period has Venue 1 (40 seats) and Venue 2 (70 seats).

find_q1_day_assignment <- function(conflict_matrix, course_sizes) {
  course_names <- rownames(conflict_matrix)
  course_sizes <- course_sizes[course_names]
  n_courses <- length(course_names)

  try_days <- function(day_limit) {
    assigned_day <- integer(n_courses)
    day_counts <- integer(day_limit)
    large_course_counts <- integer(day_limit)

    # Try a day for the next course. Undo the choice if later courses do not fit.
    search <- function(position, used_days) {
      if (position > n_courses) return(TRUE)
      course_index <- position
      size <- course_sizes[[course_index]]
      last_day <- min(day_limit, used_days + 1L)

      for (day in seq_len(last_day)) {
        # Four room/time slots per day, but only two can hold over 40 students.
        if (day_counts[[day]] >= 4L || size > 70L) next
        if (size > 40L && large_course_counts[[day]] >= 2L) next
        same_day <- which(assigned_day == day)
        if (length(same_day) > 0L &&
            any(conflict_matrix[course_index, same_day] > 0L)) next

        assigned_day[[course_index]] <<- day
        day_counts[[day]] <<- day_counts[[day]] + 1L
        if (size > 40L) large_course_counts[[day]] <<- large_course_counts[[day]] + 1L
        if (search(position + 1L, max(used_days, day))) return(TRUE)
        if (size > 40L) large_course_counts[[day]] <<- large_course_counts[[day]] - 1L
        day_counts[[day]] <<- day_counts[[day]] - 1L
        assigned_day[[course_index]] <<- 0L
      }
      FALSE
    }

    if (search(1L, 0L)) assigned_day else NULL
  }

  # Trying smaller day limits first makes the first solution a minimum.
  for (day_limit in seq_len(n_courses)) {
    assignment <- try_days(day_limit)
    if (!is.null(assignment)) {
      return(list(day = assignment, minimum_days = max(assignment)))
    }
  }
  stop("No timetable found within the available room and daily-slot constraints.",
       call. = FALSE)
}

find_q1_initial_session_assignment <- function(conflict_matrix, course_sizes) {
  course_names <- rownames(conflict_matrix)
  course_sizes <- course_sizes[course_names]
  n_courses <- length(course_names)
  try_session_count <- function(session_count) {
    assigned_session <- integer(n_courses)
    session_counts <- integer(session_count)
    session_large_count <- integer(session_count)

    search <- function(position, used_sessions) {
      if (position > n_courses) return(TRUE)
      course_index <- position
      size <- course_sizes[[course_index]]
      last_session <- min(session_count, used_sessions + 1L)

      for (session in seq_len(last_session)) {
        if (session_counts[[session]] >= 2L) next
        if (size > 70L || (size > 40L && session_large_count[[session]] >= 1L)) next
        same_session <- which(assigned_session == session)
        if (length(same_session) > 0L &&
            any(conflict_matrix[course_index, same_session] > 0L)) next

        assigned_session[[course_index]] <<- session
        session_counts[[session]] <<- session_counts[[session]] + 1L
        if (size > 40L) {
          session_large_count[[session]] <<- session_large_count[[session]] + 1L
        }
        if (search(position + 1L, max(used_sessions, session))) return(TRUE)
        if (size > 40L) {
          session_large_count[[session]] <<- session_large_count[[session]] - 1L
        }
        session_counts[[session]] <<- session_counts[[session]] - 1L
        assigned_session[[course_index]] <<- 0L
      }
      FALSE
    }

    if (search(1L, 0L)) assigned_session else NULL
  }

  # A session is one time period, shared by both venues. Try every allowed
  # period for each course, starting with one period, then two, and so on.
  # Opening only the next unused period avoids repeating equivalent schedules.
  for (session_count in seq_len(n_courses)) {
    assignment <- try_session_count(session_count)
    if (!is.null(assignment)) {
      return(list(session = assignment, minimum_sessions = max(assignment)))
    }
  }
  stop("No non-concurrent timetable found within the venue capacities.", call. = FALSE)
}

build_q1_initial_timetable <- function(courses, conflict_matrix) {
  course_names <- rownames(conflict_matrix)
  course_sizes <- lengths(courses)[course_names]
  venue_capacities <- c(40L, 70L)
  session_result <- find_q1_initial_session_assignment(conflict_matrix, course_sizes)
  session_assignment <- session_result$session
  rows <- vector("list", length(course_names))

  for (session in seq_len(session_result$minimum_sessions)) {
    members <- which(session_assignment == session)
    if (length(members) == 0L) next
    # Put the smaller exam in Venue 1 first, leaving Venue 2 for a larger exam.
    member_order <- members[order(course_sizes[members])]
    venue_used <- integer(0)
    for (course_index in member_order) {
      allowed <- if (course_sizes[[course_index]] <= venue_capacities[[1L]]) {
        c(1L, 2L)
      } else {
        2L
      }
      venue <- allowed[!allowed %in% venue_used][[1L]]
      venue_used <- c(venue_used, venue)
      day <- (session + 1L) %/% 2L
      period <- if (session %% 2L == 1L) "Morning" else "Afternoon"
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
       minimum_sessions = session_result$minimum_sessions)
}

assign_q1_venue_slots <- function(courses, day_assignment) {
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

  for (day in seq_len(max(day_assignment))) {
    day_courses <- which(day_assignment == day)
    course_order <- day_courses[order(-course_sizes[day_courses], course_names[day_courses])]
    occupied <- logical(nrow(slot_table))
    for (course_index in course_order) {
      # Place larger courses first. Small courses use Venue 1 where possible.
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

validate_q1_timetable <- function(timetable, conflict_matrix) {
  validate_q1_initial_timetable(timetable, conflict_matrix)
  for (i in seq_len(nrow(timetable))) {
    for (j in seq_len(i - 1L)) {
      a <- timetable$course[[i]]
      b <- timetable$course[[j]]
      if (timetable$day[[i]] == timetable$day[[j]] &&
          conflict_matrix[a, b] > 0L) {
        stop("Timetable places shared students in exams on the same day.",
             call. = FALSE)
      }
    }
  }
  invisible(TRUE)
}

validate_q1_initial_timetable <- function(timetable, conflict_matrix) {
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

  for (i in seq_len(nrow(timetable))) {
    for (j in seq_len(i - 1L)) {
      if (timetable$day[[i]] == timetable$day[[j]] &&
          timetable$period[[i]] == timetable$period[[j]] &&
          conflict_matrix[timetable$course[[i]], timetable$course[[j]]] > 0L) {
        stop("Initial timetable has a concurrent examination conflict.", call. = FALSE)
      }
    }
  }
  invisible(TRUE)
}

generate_q1_timetable <- function(courses, conflict_matrix) {
  courses <- courses[rownames(conflict_matrix)]
  initial_timetable <- build_q1_initial_timetable(courses, conflict_matrix)
  validate_q1_initial_timetable(initial_timetable$timetable, conflict_matrix)
  assignment <- find_q1_day_assignment(conflict_matrix, lengths(courses))
  timetable <- assign_q1_venue_slots(courses, assignment$day)
  validate_q1_timetable(timetable, conflict_matrix)
  list(initial_timetable = initial_timetable$timetable,
       initial_minimum_sessions = initial_timetable$minimum_sessions,
       timetable = timetable,
       minimum_days = assignment$minimum_days,
       original_eight_slots_sufficient = initial_timetable$minimum_sessions <= 4L)
}

print_q1_timetables <- function(schedule_result) {
  cat("\nQ1(c): timetable with no concurrent shared-student exams:\n")
  cat("Each period has Venue 1 (40 seats) and Venue 2 (70 seats).\n")
  cat("Slots 1/2, 3/4, 5/6 and 7/8 are pairs at the same time,\n")
  cat("so the original eight slots provide only four time periods over two days.\n")
  cat("A positive conflict-matrix entry means the two courses cannot share a period,\n")
  cat("even in different venues. Each room/time slot holds only one course.\n")
  cat("The search tries each allowed period, undoing a choice when a later course\n")
  cat("cannot fit. It tries fewer periods first and checks conflicts and room sizes.\n")
  cat("Q1(c): the original eight slots are",
      if (schedule_result$original_eight_slots_sufficient) "sufficient.\n" else "insufficient.\n")
  if (!schedule_result$original_eight_slots_sufficient) {
    cat("No assignment in four periods satisfies those constraints.\n")
  }
  cat("The first valid timetable uses", schedule_result$initial_minimum_sessions,
      "time periods over", max(schedule_result$initial_timetable$day), "days.\n")
  cat("Slot numbering continues with four room/time slots per extra day.\n")
  print(schedule_result$initial_timetable, row.names = FALSE)

  cat("\nQ1(d): updated timetable with no same-day back-to-back exams:\n")
  cat("Morning and afternoon are the only periods in a day, so courses with\n")
  cat("shared students must be on different days. Consecutive days are allowed.\n")
  cat("For each course, try a day with no shared-student course already on it.\n")
  cat("Check that its rooms fit too; undo unsuccessful choices and try another day.\n")
  cat("Trying fewer days first gives", schedule_result$minimum_days,
      "days for this updated timetable.\n")
  print(schedule_result$timetable, row.names = FALSE)
  invisible(NULL)
}

write_q1_timetable_outputs <- function(schedule_result, project_root) {
  output_dir <- file.path(project_root, "outputs", "q1")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(schedule_result$initial_timetable,
                   file.path(output_dir, "concurrent_conflict_timetable.csv"),
                   row.names = FALSE)
  utils::write.csv(schedule_result$timetable,
                   file.path(output_dir, "examination_timetable.csv"),
                   row.names = FALSE)
  # Both timetables passed the validators before reaching this export.
  validation <- data.frame(
    courses_scheduled = nrow(schedule_result$initial_timetable),
    initial_time_periods_required = schedule_result$initial_minimum_sessions,
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

if (sys.nframe() == 0L) {
  if (!exists("q1_find_project_root", mode = "function")) {
    source(file.path("assignment_files", "q1_clean.R"), local = TRUE)
  }
  source(file.path("assignment_files", "q1_conflict.R"), local = TRUE)
  root <- q1_find_project_root()
  clean_path <- file.path(root, "outputs", "q1", "courses_clean.rds")
  if (!file.exists(clean_path)) {
    stop("Run assignment_files/q1_clean.R first to create the cleaned registration lists.",
         call. = FALSE)
  }
  courses <- readRDS(clean_path)
  conflict_matrix <- build_q1_conflict_matrix(courses)
  result <- generate_q1_timetable(courses, conflict_matrix)
  write_q1_timetable_outputs(result, root)
  print_q1_timetables(result)
}
