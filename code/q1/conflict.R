# Load cleaned data ====
courses <- readRDS("data/processed/q1/courses_clean.rds")
codes   <- names(courses)
sizes   <- lengths(courses)

sizes

# Using pairwise overlap with intersect function (conflict matrix) ====
overlap <- function(a, b) length(intersect(courses[[a]], courses[[b]]))

conf <- outer(codes, codes, Vectorize(overlap))
dimnames(conf) <- list(codes, codes)

conf

# Calculate incidence matrix for cross-check ====
# Create a table with one row per student and one column per course (M)
students <- sort(unique(unlist(courses)))
M <- sapply(courses, function(ids) as.integer(students %in% ids))
rownames(M) <- students

conf2 <- t(M) %*% M               # All pairwise overlaps at once

head(M, 10)                       # Peek 10 rows at the incidence matrix

# Validation ====
# Ensure both methods agree
stopifnot(all(conf == conf2))

# Checking the matrix is symmetric
stopifnot(isSymmetric(conf))

# Validate the diagonal must equal with each course sizes
stopifnot(all(diag(conf) == sizes))

upper <- upper.tri(conf)          # Creating TRUE/FALSE matrix marking the cells above the diagonal
max_overlap <- outer(sizes, sizes, pmin)

stopifnot(all(conf[upper] <= max_overlap[upper]))          # overlap cannot exceed the size of the smaller course

nrow(M)                           # Distinct students across all courses
sum(sizes)                        # Total registrations
# Checking number of students who is taking 1, 2, 3, ... courses
table(rowSums(M))

# Summary of the clashes ====
pairs <- which(upper, arr.ind = TRUE)
pair_tbl <- data.frame(
  course_a = codes[pairs[, 1]],
  course_b = codes[pairs[, 2]],
  shared   = conf[pairs],
  row.names = NULL
)

pair_tbl[order(-pair_tbl$shared), ]       # All 15 pairs, most clashes first

sum(pair_tbl$shared > 0)                  # Number of pairs that clash
pair_tbl[pair_tbl$shared == 0, ]          # List out the pairs with no clash

# Save ====
# Save conflict matrix in conf_matrix.rds for future use
dir.create("data/processed/q1", recursive = TRUE, showWarnings = FALSE)
saveRDS(conf, "data/processed/q1/conf_matrix.rds")

# Save conflict matrix in csv file for easy viewing
dir.create("outputs/q1", recursive = TRUE, showWarnings = FALSE)
write.csv(conf, "outputs/q1/conflict_matrix.csv")