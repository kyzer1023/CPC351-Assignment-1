# Controlled examples for the comparison. These are not assignment inputs.

make_q1_independent_courses <- function(sizes) {
  course_names <- paste0("DEMO", seq_along(sizes))
  courses <- lapply(seq_along(sizes), function(i) {
    paste0(course_names[[i]], "_student", seq_len(sizes[[i]]))
  })
  setNames(courses, course_names)
}

q1_synthetic_cases <- function() {
  list(
    small_independent = make_q1_independent_courses(rep(15L, 6L)),
    medium_independent = make_q1_independent_courses(rep(41L, 6L)),
    oversized = make_q1_independent_courses(c(90L, 15L, 15L, 15L, 15L, 15L))
  )
}
