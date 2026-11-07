# Q1(c-d): find a capacity-feasible timetable with no shared-student exams on
# the same day. The two periods in a day are treated as back-to-back.

find_q1_day_assignment <- function(conflict_matrix, max_courses_per_day = 4L) {
  course_names <- rownames(conflict_matrix)
  n_courses <- length(course_names)
  degree <- rowSums(conflict_matrix > 0)
  order_by_degree <- order(-degree, course_names)

  try_days <- function(day_limit) {
    assigned_day <- integer(n_courses)
    day_counts <- integer(day_limit)

    search <- function(position, used_days) {
      if (position > n_courses) return(TRUE)
      course_index <- order_by_degree[[position]]
      last_day <- min(day_limit, used_days + 1L)

      for (day in seq_len(last_day)) {
        if (day_counts[[day]] >= max_courses_per_day) next
        same_day <- which(assigned_day == day)
        if (length(same_day) > 0L &&
            any(conflict_matrix[course_index, same_day] > 0L)) next

        assigned_day[[course_index]] <<- day
        day_counts[[day]] <<- day_counts[[day]] + 1L
        if (search(position + 1L, max(used_days, day))) return(TRUE)
        day_counts[[day]] <<- day_counts[[day]] - 1L
        assigned_day[[course_index]] <<- 0L
      }
      FALSE
    }

    if (search(1L, 0L)) assigned_day else NULL
  }

  for (day_limit in seq_len(n_courses)) {
    assignment <- try_days(day_limit)
    if (!is.null(assignment)) {
      return(list(day = assignment, minimum_days = max(assignment)))
    }
  }
  stop("No timetable found within the available room and daily-slot constraints.",
       call. = FALSE)
}

find_q1_initial_session_assignment <- function(conflict_matrix, course_sizes,
                                               venue_capacities = c(40L, 70L)) {
  course_names <- rownames(conflict_matrix)
  n_courses <- length(course_names)
  degree <- rowSums(conflict_matrix > 0L)
  order_by_degree <- order(-degree, -course_sizes, course_names)
  try_session_count <- function(session_count) {
    assigned_session <- integer(n_courses)
    session_counts <- integer(session_count)
    session_large_count <- integer(session_count)

    search <- function(position, used_sessions) {
      if (position > n_courses) return(TRUE)
      course_index <- order_by_degree[[position]]
      size <- course_sizes[[course_index]]
      last_session <- min(session_count, used_sessions + 1L)

      for (session in seq_len(last_session)) {
        if (session_counts[[session]] >= 2L) next
        if (size > venue_capacities[[2L]] ||
            (size > venue_capacities[[1L]] && session_large_count[[session]] >= 1L)) next
        same_session <- which(assigned_session == session)
        if (length(same_session) > 0L &&
            any(conflict_matrix[course_index, same_session] > 0L)) next

        assigned_session[[course_index]] <<- session
        session_counts[[session]] <<- session_counts[[session]] + 1L
        if (size > venue_capacities[[1L]]) {
          session_large_count[[session]] <<- session_large_count[[session]] + 1L
        }
        if (search(position + 1L, max(used_sessions, session))) return(TRUE)
        if (size > venue_capacities[[1L]]) {
          session_large_count[[session]] <<- session_large_count[[session]] - 1L
        }
        session_counts[[session]] <<- session_counts[[session]] - 1L
        assigned_session[[course_index]] <<- 0L
      }
      FALSE
    }

    if (search(1L, 0L)) assigned_session else NULL
  }

  for (session_count in seq_len(n_courses)) {
    assignment <- try_session_count(session_count)
    if (!is.null(assignment)) {
      return(list(session = assignment, minimum_sessions = max(assignment)))
    }
  }
  stop("No non-concurrent timetable found within the venue capacities.", call. = FALSE)
}

build_q1_initial_timetable <- function(courses, conflict_matrix,
                                       venue_capacities = c(40L, 70L)) {
  course_names <- names(courses)
  course_sizes <- lengths(courses)
  session_result <- find_q1_initial_session_assignment(
    conflict_matrix, course_sizes, venue_capacities = venue_capacities
  )
  session_assignment <- session_result$session
  rows <- vector("list", length(course_names))

  for (session in seq_len(session_result$minimum_sessions)) {
    members <- which(session_assignment == session)
    if (length(members) == 0L) next
    member_order <- members[order(course_sizes[members] > venue_capacities[[1L]],
                                  -course_sizes[members], course_names[members])]
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

assign_q1_venue_slots <- function(courses, day_assignment,
                                  venue_capacities = c(40L, 70L)) {
  course_names <- names(courses)
  course_sizes <- lengths(courses)
  if (any(course_sizes > max(venue_capacities))) {
    stop("At least one course exceeds the largest venue capacity (70).", call. = FALSE)
  }

  slot_table <- data.frame(
    local_slot = 1:4,
    period = c("Morning", "Morning", "Afternoon", "Afternoon"),
    venue = c("Venue 1", "Venue 2", "Venue 1", "Venue 2"),
    capacity = c(venue_capacities[[1L]], venue_capacities[[2L]],
                 venue_capacities[[1L]], venue_capacities[[2L]]),
    stringsAsFactors = FALSE
  )
  schedule <- vector("list", max(day_assignment))

  for (day in seq_len(max(day_assignment))) {
    day_courses <- which(day_assignment == day)
    course_order <- day_courses[order(-course_sizes[day_courses], course_names[day_courses])]
    occupied <- logical(nrow(slot_table))
    slot_by_course <- integer(length(course_names))

    place_next <- function(position) {
      if (position > length(course_order)) return(TRUE)
      course_index <- course_order[[position]]
      size <- course_sizes[[course_index]]
      preferred_slots <- if (size <= venue_capacities[[1L]]) {
        c(1L, 3L, 2L, 4L)
      } else {
        c(2L, 4L)
      }
      for (slot in preferred_slots) {
        if (occupied[[slot]] || size > slot_table$capacity[[slot]]) next
        occupied[[slot]] <<- TRUE
        slot_by_course[[course_index]] <<- slot
        if (place_next(position + 1L)) return(TRUE)
        slot_by_course[[course_index]] <<- 0L
        occupied[[slot]] <<- FALSE
      }
      FALSE
    }

    if (!place_next(1L)) {
      stop("Unable to place all courses into the available venues and periods.",
           call. = FALSE)
    }

    for (course_index in day_courses) {
      slot <- slot_by_course[[course_index]]
      schedule[[day]][[length(schedule[[day]]) + 1L]] <- data.frame(
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

  result <- do.call(rbind, unlist(schedule, recursive = FALSE))
  result <- result[order(result$day, match(result$period, c("Morning", "Afternoon")),
                         match(result$venue, c("Venue 1", "Venue 2"))), ]
  rownames(result) <- NULL
  result
}

validate_q1_timetable <- function(timetable, conflict_matrix) {
  if (any(timetable$students > timetable$capacity)) {
    stop("Timetable violates a venue capacity.", call. = FALSE)
  }
  if (anyDuplicated(timetable$course) > 0L) {
    stop("A course was scheduled more than once.", call. = FALSE)
  }
  if (!setequal(timetable$course, rownames(conflict_matrix))) {
    stop("Timetable does not schedule exactly the six courses.", call. = FALSE)
  }
  for (i in seq_len(nrow(timetable) - 1L)) {
    for (j in seq.int(i + 1L, nrow(timetable))) {
      a <- timetable$course[[i]]
      b <- timetable$course[[j]]
      if (timetable$day[[i]] == timetable$day[[j]] &&
          conflict_matrix[a, b] > 0L) {
        stop("Timetable places shared students in exams on the same day.",
             call. = FALSE)
      }
      if (timetable$day[[i]] == timetable$day[[j]] &&
          timetable$slot[[i]] == timetable$slot[[j]] &&
          conflict_matrix[a, b] > 0L) {
        stop("Timetable has a concurrent examination conflict.", call. = FALSE)
      }
    }
  }
  invisible(TRUE)
}

validate_q1_initial_timetable <- function(timetable, conflict_matrix) {
  if (any(timetable$students > timetable$capacity) ||
      anyDuplicated(timetable$course) > 0L ||
      !setequal(timetable$course, rownames(conflict_matrix))) {
    stop("Initial timetable violates course coverage or venue capacity.", call. = FALSE)
  }
  for (i in seq_len(nrow(timetable) - 1L)) {
    for (j in seq.int(i + 1L, nrow(timetable))) {
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
  initial_timetable <- build_q1_initial_timetable(courses, conflict_matrix)
  validate_q1_initial_timetable(initial_timetable$timetable, conflict_matrix)
  assignment <- find_q1_day_assignment(conflict_matrix)
  timetable <- assign_q1_venue_slots(courses, assignment$day)
  validate_q1_timetable(timetable, conflict_matrix)
  list(initial_timetable = initial_timetable$timetable,
       initial_minimum_sessions = initial_timetable$minimum_sessions,
       timetable = timetable,
       minimum_days = assignment$minimum_days,
       original_eight_slots_sufficient = initial_timetable$minimum_sessions <= 4L)
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
  cat("Concurrent-conflict timetable (extended if eight slots are insufficient):\n")
  print(result$initial_timetable, row.names = FALSE)
  cat("\nUpdated no-back-to-back timetable:\n")
  print(result$timetable, row.names = FALSE)
  message("Q1(c): the original eight slots are ",
          if (result$original_eight_slots_sufficient) "sufficient" else "insufficient",
          " for concurrent-conflict and capacity constraints.")
  message("Q1(d): the updated no-back-to-back timetable requires ",
          result$minimum_days, " days.")
}
