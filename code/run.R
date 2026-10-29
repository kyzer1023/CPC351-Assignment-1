# Baseline runner. Usage: Rscript code/run.R [all|q1|q2] [travel_csv]
# Scheduling, data cleaning, and routing will be added in the question modules.

locate_project_root <- function() {
  file_argument <- grep("^--file=", commandArgs(), value = TRUE)
  starting_points <- getwd()

  if (length(file_argument) > 0L) {
    script_path <- sub("^--file=", "", file_argument[[1L]])
    starting_points <- c(dirname(script_path), starting_points)
  }

  for (start in starting_points) {
    candidate <- normalizePath(start, winslash = "/", mustWork = TRUE)
    repeat {
      if (file.exists(file.path(candidate, "CPC351-Assignment-1.Rproj")) &&
          file.exists(file.path(candidate, "code", "run.R"))) {
        return(candidate)
      }

      parent <- dirname(candidate)
      if (identical(parent, candidate)) break
      candidate <- parent
    }
  }

  stop("Cannot find the project root. Open the .Rproj file or run code/run.R by its path.",
       call. = FALSE)
}

project_root <- locate_project_root()
source(file.path(project_root, "code", "common", "io.R"), local = TRUE)
source(file.path(project_root, "code", "q1", "main.R"), local = TRUE)
source(file.path(project_root, "code", "q2", "main.R"), local = TRUE)

arguments <- commandArgs(trailingOnly = TRUE)
mode <- if (length(arguments) == 0L) "all" else tolower(arguments[[1L]])

if (!mode %in% c("all", "q1", "q2") || length(arguments) > 2L ||
    (mode == "q1" && length(arguments) > 1L)) {
  stop("Usage: Rscript code/run.R [all|q1|q2] [travel_csv]", call. = FALSE)
}

travel_csv <- if (length(arguments) == 2L) {
  path.expand(arguments[[2L]])
} else {
  file.path(project_root, "data", "raw", "q2", "ahmad_travel_logs.csv")
}

message("Running baseline input checks. Assignment algorithms are still pending.")
baseline_results <- list()

if (mode %in% c("all", "q1")) {
  baseline_results$q1 <- inspect_q1_inputs(project_root)
}
if (mode %in% c("all", "q2")) {
  baseline_results$q2 <- inspect_q2_inputs(project_root, travel_csv)
}

invisible(baseline_results)
