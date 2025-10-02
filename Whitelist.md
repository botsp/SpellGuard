  # Hard-coded internal vocabulary whitelist (auto-included)
  project_vocab <- c("Takeda", "ADaM", "aCRF", "Num", "Codelist", "TypeODM","Timepoint")


## 1. SDTM CT list
````
# Load required packages
library(openxlsx)
library(dplyr)

# Read the Excel file
file_path <- "C:/Users/KS/OneDrive/desktop/pytest/spell_check_results.xlsx"
data <- read.xlsx(file_path, sheet = 1)  # Specify sheet (e.g., 1 for first sheet)

# Select distinct values from a specific column, excluding those containing a semicolon
sdtmct_vocab <- data %>%
  select(MisspelledWords) %>%  # Replace with your column name
  filter(!grepl(";", MisspelledWords)) %>%  # Exclude values containing ';'
  distinct() %>%
  pull()  # Get as a vector

# Write to a text file
output_file <- "C:/Users/KS/OneDrive/desktop/pytest/sdtmct_vocab.txt"
writeLines(project_vocab, output_file)

# View the result
print(sdtmct_vocab)
````

## 2. ADam CT list
adamct_vocab <- c("ADaMIG","subscores","Vugrin", "Rostron", "Verzi", "Brodsky", "Choiniere", "Coleman", "Paredes", "Apelberg", "PLoS")
