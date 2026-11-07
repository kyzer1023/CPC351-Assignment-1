# Loading Data into R ====
getwd()
list.files("data/raw/q1")

# Stores the txt file paths and load the six files
files <- list.files("data/raw/q1", pattern = "^Q1_.*\\.txt$", full.names = TRUE)

raw <- lapply(files, readLines, warn = FALSE)
names(raw) <- gsub("^Q1_|\\.txt$", "", basename(files))

# Showing type and size of each course
str(raw)

# Checking number of lines per course
sapply(raw, length)

# Showing first 10 lines of each course
lapply(raw, head, 10)

# Inspect raw data ====
# Build one table with column course, raw text, prefix (letters), digits
split_id <- function(x, course) {
  x <- trimws(x)
  data.frame(
    course     = course,
    raw        = x,
    prefix     = sub("\\d.*$", "", x),     # everything before the first digit
    digits     = gsub("\\D", "", x),       # digits only
    digit_len  = nchar(gsub("\\D", "", x)),
    stringsAsFactors = FALSE
  )
}

parts <- do.call(rbind, Map(split_id, raw, names(raw)))
rownames(parts) <- NULL

head(parts, 15)
table(parts$prefix)                 # which prefixes exist (NAME-, NAME_, NEMA-, ...)
table(parts$prefix, parts$course)   # prefix by course
table(parts$digit_len)              # digit lengths: 2 and 3 mean missing zeros

# Data Cleaning ====
# Identity is decided by the number as the prefix and separator are dirty and inconsistent
# NEMA is a typo of NAME
# Pad to 3 digits
# Format in NAME### to ensure consistency
parts$id_num  <- as.integer(parts$digits)
parts$clean   <- sprintf("NAME%03d", parts$id_num)
# FALSE = text already in NAME### form, TRUE = text rewritten to NAME### form
parts$changed <- parts$raw != parts$clean 

# Checking and comparing the rewritten text and raw text
table(parts$changed)                                           
head(parts[parts$changed, c("course", "raw", "clean")], 20)    # changed rows
parts[grepl("^NEMA", parts$raw), c("course", "raw", "clean")]  # typo rule
parts[parts$digit_len < 3, c("course", "raw", "clean")]        # padding rule

# Checks after standardising ====
# Duplicates inside the same course
dup_rows <- duplicated(parts[, c("course", "clean")])
parts[dup_rows | duplicated(parts[, c("course", "clean")], fromLast = TRUE),
      c("course", "raw", "clean")]

# ID range per course (look for outliers)
range(parts$id_num)
tapply(parts$id_num, parts$course, range)

# Create a boxplot and a stripchart for checking the outliers
boxplot(id_num ~ course, data = parts,
        main = "Student ID number by course (range check)",
        xlab = "Course", ylab = "ID number")

stripchart(id_num ~ course, data = parts, method = "jitter",
           vertical = TRUE, pch = 16, col = rgb(0, 0, 0, 0.4),
           main = "Every student ID by course", ylab = "ID number")

# Finding students who are not registered in any course
ids_all <- sort(unique(parts$id_num))
length(ids_all)                       # distinct students across all courses
setdiff(1:167, ids_all)               # numbers that appear in no course

# Build final list ====
# Removing duplicate registrations
parts_clean <- parts[!dup_rows, ]
rownames(parts_clean) <- NULL
nrow(parts)    
nrow(parts_clean)

# Final list that sorted unique student IDs
courses <- lapply(split(parts_clean$clean, parts_clean$course), sort)

# Audit table
audit <- data.frame(
  course  = names(courses),
  raw     = as.vector(table(parts$course)[names(courses)]),
  changed = as.vector(tapply(parts$changed, parts$course, sum)[names(courses)]),
  dup     = as.vector(tapply(dup_rows, parts$course, sum)[names(courses)]),
  clean   = sapply(courses, length),
  row.names = NULL
)
audit

# Safety checks and save ====
stopifnot(!anyNA(parts$id_num))                              # every line had digits
stopifnot(all(grepl("^NAME\\d{3}$", unlist(courses))))       # every ID is NAME###
stopifnot(sum(audit$raw) - sum(audit$dup) == sum(audit$clean))

# Saving the result
# Save result into rds file for future use
dir.create("data/processed/q1", recursive = TRUE, showWarnings = FALSE)
saveRDS(courses, "data/processed/q1/courses_clean.rds")

# Save result as txt files for ease to read
for (nm in names(courses)) {
  writeLines(courses[[nm]], paste0("data/processed/q1/", nm, "_clean.txt"))
}

# Exploratory Data Analysis on clean data ====
sizes <- sapply(courses, length)

# Create a bar chart for visualisation
# x-axis = course code, y-axis = number of students
bp <- barplot(sizes,
              ylim = c(0, 80),
              main = "Students per course (after cleaning)",
              xlab = "Course", ylab = "Number of students",
              col  = ifelse(sizes <= 40, "blue", "orange"))

# Plot dashed line for showing the venue capacities
abline(h = c(40, 70), lty = 2)
text(x = max(bp) + 0.6, y = c(40, 70) + 2,
     labels = c("Venue 1 capacity (40)", "Venue 2 capacity (70)"),
     adj = 1, cex = 0.8)

# Showing the number of students on each course
text(bp, sizes + 2, labels = sizes)

# Providing legend showing the meaning of color
legend("topleft", fill = c("blue", "orange"),
       legend = c("Fits Venue 1 or 2 (<= 40)", "Fits Venue 2 only (41-70)"),
       cex = 0.8, bty = "n")
