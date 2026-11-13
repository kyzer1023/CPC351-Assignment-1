# Reproduce the comparison figures with base R. Run from the repository root:
# Rscript evidence/q1_rooms/q1_compare_rooms.R

source("assignment_files/q1_clean.R")
source("assignment_files/q1_conflict.R")
source("assignment_files/q1_schedule.R")
source("assignment_files/q1_shared_schedule.R")
source("evidence/q1_rooms/q1_synthetic_cases.R")

summarise_q1_room_result <- function(case_name, method, result) {
  rows <- list()
  for (part in c("c", "d")) {
    table <- if (part == "c") result$initial_timetable else result$timetable
    occupied <- table[!duplicated(table$slot), ]
    rows[[part]] <- data.frame(
      dataset = case_name, method = method, part = part, feasible = TRUE,
      periods = nrow(unique(table[c("day", "period")])), days = max(table$day),
      room_bookings = nrow(occupied), registrations = sum(table$students),
      booked_seats = sum(occupied$capacity),
      unused_seats = sum(occupied$capacity) - sum(table$students),
      split_courses = sum(table(table$course) > 1L)
    )
  }
  do.call(rbind, rows)
}

draw_q1_room_comparison <- function(summary, path, synthetic = FALSE) {
  # Separate figures prevent synthetic gains being mistaken for supplied-data gains.
  case_names <- if (synthetic) c("small_independent", "medium_independent") else "provided"
  labels <- if (synthetic) {
    c("Case A: six courses of 15 students | no shared students",
      "Case B: six courses of 41 students | no shared students")
  } else {
    "Six supplied courses | 265 registrations | 167 students"
  }
  panels <- rbind(c(1L, 1L, 1L), c(2L, 2L, 2L), c(3L, 3L, 3L), c(4L, 5L, 6L))
  heights <- c(0.8, 1.1, 0.55, 3.1)
  if (synthetic) {
    panels <- rbind(panels, c(7L, 7L, 7L), c(8L, 9L, 10L))
    heights <- c(heights, 0.55, 3.1)
  }
  panels <- rbind(panels, rep(max(panels) + 1L, 3L))
  png(path, width = 1200, height = if (synthetic) 1240 else 800, res = 150)
  layout(panels, heights = c(heights, 0.8))
  par(family = "sans", col.axis = "#334155", col.lab = "#334155")
  colors <- c("#64748b", "#138477", "#7357b5")

  par(mar = c(0, 0, 0, 0))
  plot.new()
  plot.window(xlim = c(0, 100), ylim = c(0, 1), xaxs = "i", yaxs = "i")
  rect(0, 0, 100, 1, col = if (synthetic) "#fff2df" else "#e8f0f9", border = NA)
  text(2, 0.7, if (synthetic) "SYNTHETIC DATA: CONTROLLED EXAMPLES" else "PROVIDED DATA: ACTUAL RESULTS",
       adj = 0, font = 2L, cex = 1.3, col = "#0f172a")
  text(2, 0.28, if (synthetic) "Where room sharing and splitting can shorten the timetable" else
         "Same timetable length, with one fewer occupied room booking",
       adj = 0, cex = 1.05, col = "#334155")

  plot.new()
  plot.window(xlim = c(0, 100), ylim = c(0, 1), xaxs = "i", yaxs = "i")
  method_names <- c("Current", "Share rooms", "Share + split")
  descriptions <- c("One course per room.\nKeep its students together.",
                    "Compatible courses share a room.\nKeep each course together.",
                    "Also let a course use both rooms\nin the same period.")
  for (i in 1:3) {
    x <- (i - 1L) * 33.3 + 2
    rect(x, 0.69, x + 1.3, 0.86, col = colors[[i]], border = NA)
    text(x + 2, 0.77, method_names[[i]], adj = 0, font = 2L, cex = 1.1)
    text(x, 0.32, descriptions[[i]], adj = 0, cex = 0.95, col = "#334155")
  }

  for (i in seq_along(case_names)) {
    par(mar = c(0, 0, 0, 0))
    plot.new()
    plot.window(xlim = c(0, 100), ylim = c(0, 1))
    text(2, 0.5, labels[[i]], adj = 0, font = 2L, cex = 1.05, col = "#0f172a")
    par(mar = c(3, 3.5, 2, 1))
    for (measure in c("periods", "days", "room_bookings")) {
      part <- if (measure == "days") "d" else "c"
      rows <- summary[summary$dataset == case_names[[i]] & summary$part == part, ]
      rows <- rows[match(c("Current", "Share", "Share + split"), rows$method), ]
      values <- rows[[measure]]
      title <- switch(measure, periods = "Q1(c): periods", days = "Q1(d): days",
                      room_bookings = "Q1(c): room bookings")
      positions <- barplot(values, names.arg = rep("", 3L),
                           col = colors, border = NA, ylim = c(0, max(values) * 1.3),
                           las = 1L, cex.names = 1, main = title, cex.main = 1.1,
                           yaxs = "i", axes = FALSE)
      axis(2L, at = seq.int(0L, max(values)), las = 1L, cex.axis = 0.9)
      mtext(c("Current", "Share\nrooms", "Share +\nsplit"), side = 1L,
            at = positions, line = 2, cex = 0.75)
      text(positions, values, labels = values, pos = 3L, font = 2L, cex = 1.25)
    }
  }
  par(mar = c(0, 0, 0, 0))
  plot.new()
  plot.window(xlim = c(0, 100), ylim = c(0, 1))
  text(50, 0.73, if (synthetic) "These favourable cases do not predict gains on the provided data." else
         "Sharing saves one booking. Allowing splitting adds no further gain here.",
       font = 2L, cex = 1.05, col = "#334155")
  text(50, 0.25, "Lower is better. One booking = one occupied room in one period. Rooms: 40 + 70 seats.",
       cex = 0.95, col = "#475569")
  dev.off()
}

draw_q1_room_flowcharts <- function(path) {
  png(path, width = 1680, height = 1300, res = 150)
  par(mar = c(1, 1, 3, 1), family = "sans")
  plot.new()
  plot.window(xlim = c(0, 100), ylim = c(0, 108), xaxs = "i", yaxs = "i")
  title("Same search idea, different room rules", cex.main = 1.5)
  box <- function(x, y, label, color, decision = FALSE) {
    if (decision) {
      polygon(c(x - 20, x, x + 20, x), c(y, y + 5, y, y - 5),
              col = color, border = "#cbd5e1")
    } else {
      rect(x - 20, y - 4, x + 20, y + 4, col = color, border = "#cbd5e1")
    }
    text(x, y, label, cex = 0.85, col = "#0f172a")
  }
  arrow <- function(x, y) arrows(x, y - 4, x, y - 8, length = 0.08, col = "#64748b")
  for (x in c(24, 76)) {
    text(x, 103, if (x == 24) "CURRENT" else "SHARE + SPLIT", font = 2L, cex = 1.1)
    labels <- if (x == 24) {
      c("Read cleaned courses and shared-student counts",
        "Try a small period/day limit",
        "Choose a period/day for the next course",
        "No student clash, and a free whole room?",
        "All courses placed?",
        "Keep the first valid schedule",
        "One course stays together in one room")
    } else {
      c("Read the same courses and student counts",
        "Try a small period/day limit",
        "Choose a period for the next course",
        "No student clash, and enough room space?",
        "All courses placed?",
        "At this limit, keep the fewest room bookings",
        "Keep courses whole if they fit; otherwise split")
    }
    for (i in seq_along(labels)) {
      y <- 93 - (i - 1L) * 12
      # Wrap labels so the exported image remains readable.
      label <- paste(strwrap(labels[[i]], width = 43L), collapse = "\n")
      box(x, y, label, if (x == 24) "#eef2f6" else "#e6f3f0", decision = i %in% c(4L, 5L))
      if (i < length(labels)) arrow(x, y)
    }
    # Invalid choices are undone; a valid partial schedule adds another course.
    segments(x - 20, 57, x - 22, 57, col = "#64748b")
    segments(x - 22, 57, x - 22, 69, col = "#64748b")
    arrows(x - 22, 69, x - 20, 69, length = 0.08, col = "#64748b")
    text(x - 22, 62, "No:\nundo", cex = 0.6, pos = 4)
    segments(x + 20, 45, x + 22, 45, col = "#64748b")
    segments(x + 22, 45, x + 22, 69, col = "#64748b")
    arrows(x + 22, 69, x + 20, 69, length = 0.08, col = "#64748b")
    text(x + 22, 50, "No:\nnext", cex = 0.6, pos = 2)
    text(x + 1, 50, "Yes", cex = 0.65, pos = 4)
    text(x + 1, 38, "Yes", cex = 0.65, pos = 4)
  }
  text(50, 11, "Q1(c): shared students need different periods.  Q1(d): they need different days.",
       cex = 0.95, font = 2L)
  text(50, 6, "If a limit has no valid schedule, add one period/day and repeat.", cex = 0.95)
  text(50, 1, "A split exam is simultaneous. Every student receives exactly one room assignment.",
       cex = 0.95, col = "#475569")
  dev.off()
}

draw_q1_provided_rooms <- function(baseline, shared, path) {
  png(path, width = 1680, height = 920, res = 150)
  par(mfrow = c(2, 2), mar = c(1.5, 1, 3, 1), oma = c(2, 0, 3, 0), family = "sans")
  for (part in c("c", "d")) {
    for (method in c("Current", "Share + split")) {
      result <- if (method == "Current") baseline else shared
      table <- if (part == "c") result$initial_timetable else result$timetable
      periods <- sort(unique((table$day - 1L) * 2L +
                              ifelse(table$period == "Morning", 1L, 2L)))
      plot.new()
      plot.window(xlim = c(0, 3), ylim = c(0, 6.4))
      title(paste0("Q1(", part, ") | ", method), cex.main = 1.1)
      text(c(1.2, 2.3), 6.1, c("Venue 1 / 40 seats", "Venue 2 / 70 seats"), cex = 0.85)
      for (i in seq_along(periods)) {
        period <- periods[[i]]
        day <- (period + 1L) %/% 2L
        name <- if (period %% 2L == 1L) "Morning" else "Afternoon"
        text(0.05, 5.5 - i + 0.5, paste0("Day ", day, "\n", name), adj = 0, cex = 0.8)
        for (room in 1:2) {
          rows <- table[table$day == day & table$period == name &
                          table$venue == paste("Venue", room), ]
          x <- c(1.2, 2.3)[[room]]
          rect(x - 0.48, 5.5 - i, x + 0.48, 6.5 - i,
               col = if (nrow(rows) == 0L) "#f1f5f9" else "#dceee9", border = "white")
          label <- if (nrow(rows) == 0L) "Unused" else {
            paste(paste0(rows$course, " (", rows$students, ")"), collapse = "\n")
          }
          text(x, 6 - i, label, cex = 0.8)
        }
      }
    }
  }
  mtext("Provided data: same timetable length, one fewer occupied room", side = 3,
        outer = TRUE, line = 1, cex = 1.2, font = 2L)
  mtext("Each row is one period. Both venues run at the same time. Numbers in brackets are students.",
        side = 1, outer = TRUE, line = 0.5, cex = 0.85)
  dev.off()
}

run_q1_room_comparison <- function() {
  root <- q1_find_project_root()
  evidence_dir <- file.path(root, "evidence", "q1_rooms")
  output_dir <- file.path(evidence_dir, "generated")
  dir.create(evidence_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  supplied <- clean_q1_registrations(read_q1_registration_lists(root))$courses
  cases <- c(list(provided = supplied), q1_synthetic_cases())
  summaries <- list()
  for (case_name in names(cases)) {
    courses <- cases[[case_name]]
    conflict <- build_q1_conflict_matrix(courses)
    input <- do.call(rbind, lapply(names(courses), function(course) {
      data.frame(course = course, student = courses[[course]])
    }))
    write.csv(input, file.path(output_dir, paste0(case_name, "_registrations.csv")), row.names = FALSE)
    for (method in c("Current", "Share", "Share + split")) {
      result <- tryCatch({
        if (method == "Current") generate_q1_timetable(courses, conflict) else {
          generate_q1_shared_timetables(courses, conflict, allow_splitting = method == "Share + split")
        }
      }, error = function(e) {
        # The oversized case deliberately exceeds the whole-room models.
        expected <- if (method == "Current") "venue capacities" else "No shared-room timetable"
        if (case_name != "oversized" || method == "Share + split" ||
            !grepl(expected, conditionMessage(e), fixed = TRUE)) stop(e)
        NULL
      })
      if (is.null(result)) {
        summary <- data.frame(dataset = case_name, method = method, part = c("c", "d"),
                              feasible = FALSE, periods = NA_integer_, days = NA_integer_,
                              room_bookings = NA_integer_, registrations = sum(lengths(courses)),
                              booked_seats = NA_integer_, unused_seats = NA_integer_,
                              split_courses = NA_integer_)
      } else {
        summary <- summarise_q1_room_result(case_name, method, result)
        case_dir <- file.path(output_dir, case_name, make.names(method))
        dir.create(case_dir, recursive = TRUE, showWarnings = FALSE)
        write.csv(result$initial_timetable, file.path(case_dir, "q1c_rooms.csv"), row.names = FALSE)
        write.csv(result$timetable, file.path(case_dir, "q1d_rooms.csv"), row.names = FALSE)
        if (method != "Current") {
          write.csv(result$initial_allocation, file.path(case_dir, "q1c_students.csv"), row.names = FALSE)
          write.csv(result$updated_allocation, file.path(case_dir, "q1d_students.csv"), row.names = FALSE)
        }
        if (case_name == "provided" && method == "Current") baseline <- result
        if (case_name == "provided" && method == "Share + split") shared <- result
      }
      summaries[[length(summaries) + 1L]] <- summary
    }
  }
  summary <- do.call(rbind, summaries)
  rownames(summary) <- NULL
  write.csv(summary, file.path(evidence_dir, "comparison.csv"), row.names = FALSE, na = "")
  draw_q1_room_comparison(summary, file.path(evidence_dir, "provided_comparison.png"))
  draw_q1_room_comparison(summary, file.path(evidence_dir, "synthetic_comparison.png"), synthetic = TRUE)
  draw_q1_room_flowcharts(file.path(evidence_dir, "algorithm_flowcharts.png"))
  draw_q1_provided_rooms(baseline, shared, file.path(evidence_dir, "provided_timetables.png"))
  print(summary, row.names = FALSE)
  cat("\nFigures: evidence/q1_rooms/. Detailed tables: evidence/q1_rooms/generated/.\n")
  invisible(summary)
}

if (sys.nframe() == 0L) run_q1_room_comparison()
