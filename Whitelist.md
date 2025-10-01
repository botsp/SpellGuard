  # Hard-coded internal vocabulary whitelist (auto-included)
  project_vocab <- c("Takeda", "ADaM", "aCRF", "Num", "Codelist", "TypeODM","Timepoint")


# 1. SDTM CT list
````
# Load required packages
library(openxlsx)
library(dplyr)

# Read the Excel file
file_path <- "C:/Users/KS/OneDrive/桌面/pytest/spell_check_results.xlsx"
data <- read.xlsx(file_path, sheet = 1)  # Specify sheet (e.g., 1 for first sheet)

# Select distinct values from a specific column, excluding those containing a semicolon
sdtmct_vocab <- data %>%
  select(MisspelledWords) %>%  # Replace with your column name
  filter(!grepl(";", MisspelledWords)) %>%  # Exclude values containing ';'
  distinct() %>%
  pull()  # Get as a vector

# View the result
print(sdtmct_vocab)
````
