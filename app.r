library(shiny)
library(openxlsx)
library(hunspell)
library(DT)
library(stringr)
options(shiny.maxRequestSize = 100*1024^2) # 100 MB

# Converts (row, col) to Excel cell address (e.g., (6,2) -> B6)
cellLabel <- function(row, col) {
  label <- ""
  while (col > 0) {
    rem <- (col - 1) %% 26
    label <- paste0(LETTERS[rem + 1], label)
    col <- (col - rem - 1) %/% 26
  }
  paste0(label, row)
}

# Returns TRUE if the word contains only letters and all are uppercase
is_all_upper_word <- function(word) {
  txt <- gsub("[^A-Za-z]", "", word)
  nzchar(txt) && txt == toupper(txt)
}

# Returns TRUE if the word contains only letters and all are uppercase or contain numbers
is_all_upper_or_digit <- function(word) {
  txt <- gsub("[^A-Za-z]", "", word)
  has_letter <- nzchar(txt)
  all_upper <- has_letter && txt == toupper(txt)
  has_digit <- grepl("[0-9]", word)
  all_upper || has_digit
}


# Spell check using batch+unique, returning misspelled words in original casing/form
sheet_results <- function(df, sheet, ignore_upper = TRUE, whitelist = character()) {
  nrow_df <- nrow(df)
  ncol_df <- ncol(df)
  if (nrow_df == 0 || ncol_df == 0) return(NULL)
  cell_map <- list()
  cell_idx <- 0
  # 1: Map each cell to list of words (original)
  for (row in seq_len(nrow_df)) {
    for (col in seq_len(ncol_df)) {
      val <- as.character(df[row, col])
      val = gsub("(\r|_x000D_)", "\n", val)
      if (!is.na(val) && nchar(trimws(val)) > 0 && grepl("[a-zA-Z]", val)) {
        words <- unlist(str_extract_all(val, "\\b[\\w'-]+\\b"))
        # Split all compound words containing underscores or hyphens
        words_exploded <- unlist(strsplit(words, "[-_]"))
        words_exploded <- words_exploded[nzchar(words_exploded)]
        
        # skip hunspell if all-upper or contains number after split
        mask_upper_or_digit <- grepl("^[A-Z]+$", words_exploded) | grepl("[0-9]", words_exploded)
        check_words <- words_exploded[!mask_upper_or_digit]
        check_words <- words_exploded[!mask_upper_or_digit]
        if (ignore_upper) {
          mask_upper_only <- grepl("^[A-Z]+$", check_words)
          check_words <- check_words[!mask_upper_only]
        }
        
        keep_idx <- !check_words %in% whitelist
        check_words <- check_words[keep_idx]

        if (length(check_words) > 0) {
          cell_idx <- cell_idx + 1
          cell_map[[cell_idx]] <- list(
            cell = cellLabel(row, col),
            Sheet = sheet,
            OriginalText = val,
            Words_orig = check_words        # original-cased words
          )
        }
      }
    }
  }
  # 2: Outer unique batch spell check
  if (cell_idx == 0) return(NULL)
  words_vec <- unique(unlist(lapply(cell_map, function(x) x$Words_orig)))
  check_res <- hunspell_check(words_vec)
  all_misspelled <- words_vec[!check_res]
  
  if (length(all_misspelled) == 0) return(NULL)
  # 3: For each cell, return only those misspelled words (in original spelling)
  results <- list()
  idx <- 1
  for (item in cell_map) {
    match_idx <- which(item$Words_orig %in% all_misspelled)
    miss <- item$Words_orig[match_idx]
    if (length(miss) > 0) {
      results[[idx]] <- data.frame(
        ID = paste0(item$Sheet, "_", item$cell),
        Sheet = item$Sheet,
        Cell = item$cell,
        OriginalText = item$OriginalText,
        MisspelledWords = paste(miss, collapse = "; "),
        stringsAsFactors = FALSE
      )
      idx <- idx + 1
    }
  }
  if (length(results) == 0) return(NULL)
  do.call(rbind, results)
}

ui <- fluidPage(
  titlePanel("SpellGuard"),
  sidebarLayout(
    sidebarPanel(
      fileInput("file", "Upload Excel File (.xlsx)"),
      checkboxInput("ignore_uppercase", label = "Ignore all fully capitalized words.", value = TRUE),
      uiOutput("sheet_selector"),
      textAreaInput(
        "whitelist_words",
        label = "Whitelist Words (one per line, comma, space or semicolon separated):",
        value = "", rows = 2
      ),
      downloadButton("download", "Download Spell Check Results"),
      tags$div(
        style = "font-size: 12px; color: #7d7d7d; margin-top: 10px;",
        "Note: The row number identified here starts from the first non-empty row."
      )
    ),
    mainPanel(
      DT::dataTableOutput("preview_dt"),
      textOutput("no_error_reminder")
    )
  )
)

server <- function(input, output, session) {
  
  # Internal/vectored whitelist
  user_vocab <- c("Takeda", "cdisc", "ADaM", "aCRF", "Num","num","Biostatistics","pdf" "Codelist", "codelist", "TypeODM", "Timepoint", "timepoint", "Datetime","Dataset","dataset","datasets","Datasets","yyyymmdd","date9","time5","datetime16","xlsx","Pre","re","pre","SUPPxx")
  
  # External vocab from txt file (SDTM CT)
  sdtmct_vocab <- scan("sdtmct_vocab.txt", what = character(), sep = "\n", quiet = TRUE)
  
  # ADaM CT
  adamct_vocab <- c("ADaMIG","subscores","Vugrin", "Rostron", "Verzi", "Brodsky", "Choiniere", "Coleman", "Paredes", "Apelberg", "PLoS")
  
  # SDTM metafile
  sdtmmeta_vocab <- c("Req","CRFs","gabapentin","datetime", "codelists", "Trtmnt", "Sublineage", "sublineage", "sublineages", "timeframe","explant","biomarker","Aminotransferase","contig","https","www","Acetylsalicylic","AUCs","Mitogen","immunoassays","Safranin","Propidium","phorbol","myristate","concanavalin","Ionomycin","AEs")
  
  # ADaM metafile
  adammeta_vocab <- c("Completers","Subperiod","Trt","Strat","Verif","Subper")
  
  # Takeda SDTM metafile  
  takeda_sdtmmeta_vocab <- c("SuppQUAL", "wearables", "PopPK", "analytes", "eDT", "Biomarkers", "cytochemical", "immunocytochemical", "SAEs", "eCRF", "eCRFs", "enterable", "California", "subcategorization", "programmatically", "Directionalities", "Extraintestinal", "Preplanned", "Clonus", "Reconsent", "Inevaluable", "Reassent")
  
  # Takeda ADaM metafile  
  takeda_adammeta_vocab <- c("xpt", "ne", "Subseq", "cardiodynamic", "TLFs", "TFLs", "cQT", "Pretreatment", "AVISITs", "ValueLevel", "Alloimmune", "Concom", "EuroQoL", "HRQoL", "Calgary", "Cleveland", "iDSST", "Karolinska", "thrombocytopenic", "purpura", "iTTP", "Karolinska", "MoCA", "Pouchitis", "Willebrand", "Href", "adrg", "Uppsala","WHODrug","Mutliracial","Eval","Hy's","CQs")
  
  sheets_rv <- reactiveVal(NULL)
  results_list_rv <- reactiveVal(NULL)
  
  observeEvent(input$file, {
    file_path <- input$file$datapath
    sheets <- getSheetNames(file_path)
    sheets_rv(sheets)
    
    # Combine internal and user-provided whitelists
    user_whitelist <- unlist(strsplit(input$whitelist_words, "[,;\n\r\t ]+"))
    user_whitelist <- user_whitelist[nzchar(user_whitelist)]
    
    # Combine user_vocab, sdtmct_vocab, and UI user whitelist
    whitelist <- unique(c(user_vocab,adamct_vocab,sdtmmeta_vocab,adammeta_vocab,takeda_sdtmmeta_vocab,takeda_adammeta_vocab, sdtmct_vocab, user_whitelist))
    
    withProgress(message = "Spell-checking all sheets...", value = 0, {
      res_list <- lapply(seq_along(sheets), function(i) {
        setProgress(i / length(sheets), detail = paste("Processing sheet:", sheets[i]))
        df <- read.xlsx(file_path, sheet = sheets[i], colNames = FALSE, skipEmptyRows = FALSE, skipEmptyCols = FALSE)
        sheet_results(df, sheets[i], ignore_upper = input$ignore_uppercase, whitelist = whitelist)
      })
      names(res_list) <- sheets
      results_list_rv(res_list)
    })
  })
  
  observeEvent(list(input$ignore_uppercase, input$whitelist_words), {
    req(input$file)
    file_path <- input$file$datapath
    sheets <- sheets_rv()
    if (is.null(sheets)) return()
    user_whitelist <- unlist(strsplit(input$whitelist_words, "[,;\n\r\t ]+"))
    user_whitelist <- user_whitelist[nzchar(user_whitelist)]
    
    whitelist <- unique(c(user_vocab, adamct_vocab, sdtmmeta_vocab,adammeta_vocab,takeda_sdtmmeta_vocab,takeda_adammeta_vocab, sdtmct_vocab, user_whitelist))
    
    withProgress(message = "Spell-checking all sheets...", value = 0, {
      res_list <- lapply(seq_along(sheets), function(i) {
        setProgress(i / length(sheets), detail = paste("Processing sheet:", sheets[i]))
        df <- read.xlsx(file_path, sheet = sheets[i], colNames = FALSE, skipEmptyRows = FALSE, skipEmptyCols = FALSE)
        sheet_results(df, sheets[i], ignore_upper = input$ignore_uppercase, whitelist = whitelist)
      })
      names(res_list) <- sheets
      results_list_rv(res_list)
    })
  })
  
  output$sheet_selector <- renderUI({
    req(sheets_rv())
    sheets <- sheets_rv()
    choices <- c("(All Sheets)", sheets)
    selectInput("sheet_selected", "Filter by sheet:", choices = choices, selected = choices[1])
  })
  
  filtered_sheet <- reactive({
    reslist <- results_list_rv()
    if (is.null(reslist) || is.null(input$sheet_selected)) return(data.frame())
    if (input$sheet_selected == "(All Sheets)") {
      allresults <- do.call(rbind, Filter(Negate(is.null), reslist))
      if (is.null(allresults)) return(data.frame())
      return(allresults)
    } else {
      cur <- reslist[[input$sheet_selected]]
      if (is.null(cur)) return(data.frame())
      cur
    }
  })
  
  output$preview_dt <- DT::renderDataTable({
    filtered_sheet()
  }, options = list(pageLength = 15))
  output$no_error_reminder <- renderText({
    df <- filtered_sheet()
    if (nrow(df) > 0) return("")
    if (!is.null(input$sheet_selected) && input$sheet_selected == "(All Sheets)") {
      return("No misspelled words found in any sheet.")
    } else if (!is.null(input$sheet_selected) && input$sheet_selected != "") {
      return(paste0("No misspelled words found in this sheet: ", input$sheet_selected))
    }
    ""
  })  
  
  output$download <- downloadHandler(
    filename = function() {"spell_check_results.xlsx"},
    content = function(file) {
      reslist <- results_list_rv()
      alldata <- do.call(rbind, Filter(Negate(is.null), reslist))
      write.xlsx(alldata, file)
    }
  )
}

shinyApp(ui, server)
