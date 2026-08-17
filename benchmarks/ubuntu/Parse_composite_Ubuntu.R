# Set CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

install_and_load_packages <- function(packages) {
  new_packages <- packages[!(packages %in% installed.packages()[, "Package"])]
  if (length(new_packages)) install.packages(new_packages)
  lapply(packages, library, character.only = TRUE)
}

# List of required packages
required_packages <- c("XML", "dplyr", "ggplot2", "jsonlite", "rlang")
install_and_load_packages(required_packages)

# Import required functions
library(XML)
library(dplyr)
library(ggplot2)
library(jsonlite)
library(rlang)

# Define global variables to avoid linting issues
utils::globalVariables(c("run", "value"))

# Declare global variables to avoid binding issues
run <- NULL
value <- NULL

load_xml_file <- function(xml_file) {
  if (!file.exists(xml_file)) {
    stop("XML file does not exist.")
  }
  tryCatch({
    xmlParse(xml_file)
  }, error = function(e) {
    stop("Error parsing XML file: ", e$message)
  })
}

extract_system_info <- function(system_node) {
  if (!is.null(system_node)) {
    system_info <- xmlToList(system_node)
    cat("\nSystem Information:\n")
    cat("Title:", system_info$Identifier, "\n")
    cat("Hardware:", system_info$Hardware, "\n")
    cat("Software:", system_info$Software, "\n")
    cat("User:", system_info$User, "\n")
    cat("Timestamp:", system_info$TimeStamp, "\n")
  } else {
    cat("System node not found.\n")
  }
}

process_result_node <- function(result_node, value_unit, output_dir) {
  result <- xmlToList(result_node)
  cat("\nTest Results: ", result$Title, "\n")
  cat("Test Identifier:", result$Identifier, "\n")
  cat("Title:", result$Title, "\n")
  cat("App Version:", result$AppVersion, "\n")
  cat("Arguments:", result$Arguments, "\n")
  cat("Description:", result$Description, "\n")
  cat("Scale:", result$Scale, "\n")
  cat("Display Format:", result$DisplayFormat, "\n")

  data_node <- result$Data$Entry
  if (!is.null(data_node)) {
    # Prefer the per-result <Scale> from the XML; fall back to the value_unit
    # passed in only if Scale is missing. This lets one process_xml_file call
    # handle a combined composite where c-ray, tinymembench, and aircrack-ng
    # each have different units.
    actual_unit <- if (!is.null(result$Scale) && nzchar(result$Scale)) result$Scale else value_unit
    cat("\nData Entries:\n")
    cat("Identifier:", data_node$Identifier, "\n")
    cat("Value (", actual_unit, "):", data_node$Value, "\n")
    cat("Raw String (", actual_unit, "):", data_node$RawString, "\n")

    raw_values <- strsplit(data_node$RawString, ":")[[1]]
    run_values <- as.numeric(raw_values)
    run_df <- data.frame(run = seq_along(run_values), value = run_values)

    mean_value <- mean(run_values)
    median_value <- median(run_values)
    sd_value <- sd(run_values)

    cat("\nSummary Statistics:\n")
    cat("Mean:", mean_value, "\n")
    cat("Median:", median_value, "\n")
    cat("Standard Deviation:", sd_value, "\n")

    cat("\nDetailed Run Values:\n")
    print(run_df)

    # Skip creating plots for Tinymembench results
    if (!grepl("tinymembench", result$Identifier, ignore.case = TRUE)) {
      p <- ggplot(run_df, aes(x = .data$run, y = .data$value)) +
        geom_bar(stat = "identity", fill = "blue") +
        labs(title = paste(result$Title, "Run Values"),
             x = "Run", y = paste("Value (", actual_unit, ")")) +
        theme_minimal() +
        theme(panel.background = element_rect(fill = "white", color = "white"),
              plot.background = element_rect(fill = "white", color = "white"))

      ggsave(filename = file.path(output_dir, paste0(result$Title, "_Run_Values.png")), plot = p)
    }
  } else {
    cat("Data Entry not found.\n")
  }
}

create_memory_plot <- function(result, title, value_unit, output_dir) {
  data_node <- result$Data$Entry
  if (!is.null(data_node)) {
    raw_values <- strsplit(data_node$RawString, ":")[[1]]
    run_values <- as.numeric(raw_values)
    run_df <- data.frame(Run = seq_along(run_values), Value = run_values)

    p <- ggplot(run_df, aes(x = .data$Run, y = .data$Value)) +
      geom_bar(stat = "identity", fill = "blue") +
      labs(title = paste(title, "Run Values"), x = "Run", y = paste("Value (", value_unit, ")")) +
      theme_minimal() +
      theme(panel.background = element_rect(fill = "white", color = "white"),
            plot.background = element_rect(fill = "white", color = "white"))

    ggsave(filename = file.path(output_dir, paste0(title, "_Run_Values.png")), plot = p)
  } else {
    cat(title, "Data Entry not found.\n")
  }
}

process_xml_file <- function(xml_file, benchmark_title, value_unit, output_dir) {
  xml_data <- load_xml_file(xml_file)
  cat("XML Structure:\n")
  print(xml_data)

  xml_root <- xmlRoot(xml_data)
  if (!is.null(xml_root)) {
    cat("\nPhoronixTestSuite node found.\n")
    extract_system_info(xml_root[["System"]])

    result_nodes <- xml_root[grep("Result", names(xml_root))]
    for (result_node in result_nodes) {
      process_result_node(result_node, value_unit, output_dir)
    }

    for (result_node in result_nodes) {
      result <- xmlToList(result_node)
      if (!is.null(result$Description)) {
        if (grepl("Standard Memset", result$Description, ignore.case = TRUE)) {
          create_memory_plot(result, "Memset", value_unit, output_dir)
        } else if (grepl("Standard Memcpy", result$Description, ignore.case = TRUE)) {
          create_memory_plot(result, "Memcpy", value_unit, output_dir)
        }
      }
    }
  } else {
    cat("PhoronixTestSuite node not found.\n")
  }
}

# Command-line entry point.
#
#   Rscript Parse_composite_Ubuntu.R <composite.xml> <output_dir>
#
# The CI-captured composites at benchmarks/ubuntu/composite-latest.xml and
# benchmarks/ubuntu-arm64/composite-latest.xml bundle c-ray + tinymembench +
# aircrack-ng in a single XML, so one process_xml_file call covers all three.
# The value_unit argument is a fallback label only — process_result_node reads
# the per-result <Scale> from the XML when present.
#
# No args → legacy mode that processes the three per-test-type bare-metal
# samples under benchmarks/ubuntu/{CPU,Memory,Network}/. Kept so the 2024
# sample data can still be reparsed; new captures should use the args form.
args <- commandArgs(trailingOnly = TRUE)

if (length(args) >= 2) {
  composite_xml <- args[1]
  output_dir <- args[2]
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  process_xml_file(composite_xml, "Combined Benchmark", "from <Scale>", output_dir)
} else {
  cpu_xml_file <- "benchmarks/ubuntu/CPU/CPU 12_7_2024/composite.xml"
  memory_xml_file <- "benchmarks/ubuntu/Memory/Memory 12_8_2024/composite.xml"
  network_xml_file <- "benchmarks/ubuntu/Network/Network 12_8_2024/composite.xml"

  process_xml_file(cpu_xml_file, "C-Ray Benchmark", "Seconds", "benchmarks/ubuntu/CPU")
  process_xml_file(memory_xml_file, "Memory Benchmark", "MB/s", "benchmarks/ubuntu/Memory/Graphs")
  process_xml_file(network_xml_file, "Aircrack-ng", "k/s", "benchmarks/ubuntu/Network")
}

cat("\nScript execution completed.\n")