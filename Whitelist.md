# Hard-coded internal vocabulary whitelist (auto-included)
````
project_vocab <- c("Takeda", "ADaM", "aCRF", "Num", "Codelist", "TypeODM","Timepoint")
````

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
````
adamct_vocab <- c("ADaMIG","subscores","Vugrin", "Rostron", "Verzi", "Brodsky", "Choiniere", "Coleman", "Paredes", "Apelberg", "PLoS")
````
## 3. SDTM metafile
https://library.cdisc.org/browser/#/mdr/sdtmig/3-4/classes/GeneralObservations
````
  sdtmmeta_vocab <- c("Req","CRFs","gabapentin","datetime", "codelists", "Trtmnt", "Sublineage", "sublineage", "sublineages", "timeframe","explant","biomarker","Aminotransferase","contig","https","www","Acetylsalicylic","AUCs","Mitogen","immunoassays","Safranin","Propidium","phorbol","myristate","concanavalin","Ionomycin","AEs")
````
## 4. ADaM metafile
https://library.cdisc.org/browser/#/mdr/adam/adamig-1-3/datastructures/ADSL/variablesets/Identifier

e.g. `Imput` and `Discont` are allowed abbreviations in variable labels but are also commonly used in text descriptions. They were not pre-excluded to avoid missing these abbreviations in contexts where they are not permitted.
````
adammeta_vocab <- c("Completers","Subperiod","Trt","Strat","Verif","Subper")
````

## 5. Specified metafile
````
takeda_sdtmmeta_vocab <- c("SuppQUAL", "wearables", "PopPK", "analytes", "eDT", "Biomarkers", "cytochemical", "immunocytochemical", "SAEs", "eCRF", "eCRFs", "enterable", "California", "subcategorization", "programmatically", "Directionalities", "Extraintestinal", "Preplanned", "Clonus", "Reconsent", "Inevaluable", "Reassent")
````





