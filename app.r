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

# Spell check using batch+unique, returning misspelled words in original casing/form
sheet_results <- function(df, sheet, ignore_upper = TRUE, whitelist = character()) {
  nrow_df <- nrow(df)
  ncol_df <- ncol(df)
  if (nrow_df == 0 || ncol_df == 0) return(NULL)
  cell_map <- list()
  cell_idx <- 0
  # 1: Map each cell to list of words (both original and lower-case)
  for (row in seq_len(nrow_df)) {
    for (col in seq_len(ncol_df)) {
      val <- as.character(df[row, col])
      if (!is.na(val) && nchar(trimws(val)) > 0 && grepl("[a-zA-Z]", val)) {
        words <- unlist(str_extract_all(val, "\\b[\\w'-]+\\b"))
        check_words <- if (ignore_upper) words[!sapply(words, is_all_upper_word)] else words
        keep_idx <- !tolower(check_words) %in% whitelist
        check_words <- check_words[keep_idx]
        check_words_lower <- tolower(check_words)
        if (length(check_words) > 0) {
          cell_idx <- cell_idx + 1
          cell_map[[cell_idx]] <- list(
            cell = cellLabel(row, col),
            Sheet = sheet,
            OriginalText = val,
            Words_orig = check_words,         # original-cased words
            Words_lower = check_words_lower   # lower-case for spellcheck
          )
        }
      }
    }
  }
  # 2: Outer unique batch spell check
  if (cell_idx == 0) return(NULL)
  words_vec <- unique(unlist(lapply(cell_map, function(x) x$Words_lower)))
  all_misspelled <- unique(unlist(hunspell(words_vec)))
  if (length(all_misspelled) == 0) return(NULL)
  # 3: For each cell, return only those misspelled words (in original spelling)
  results <- list()
  idx <- 1
  for (item in cell_map) {
    match_idx <- which(item$Words_lower %in% all_misspelled)
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
      DT::dataTableOutput("preview_dt")
    )
  )
)

server <- function(input, output, session) {
  
  # Hard-coded internal vocabulary whitelist (auto-included)
  project_vocab <- c("Takeda", "ADaM", "aCRF", "Num", "Codelist", "TypeODM","Timepoint")
  
  sheets_rv <- reactiveVal(NULL)
  results_list_rv <- reactiveVal(NULL)
  
  observeEvent(input$file, {
    file_path <- input$file$datapath
    sheets <- getSheetNames(file_path)
    sheets_rv(sheets)
    if (length(sheets) > 0) {
      updateSelectInput(session, "sheet_selected", choices = sheets, selected = sheets[[1]])
    }
    # Combine internal and user-provided whitelists
    user_whitelist <- tolower(unlist(strsplit(input$whitelist_words, "[,;\n\r\t ]+")))
    user_whitelist <- user_whitelist[nzchar(user_whitelist)]
    whitelist <- unique(c(tolower(project_vocab), user_whitelist))
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
    user_whitelist <- tolower(unlist(strsplit(input$whitelist_words, "[,;\n\r\t ]+")))
    user_whitelist <- user_whitelist[nzchar(user_whitelist)]
    whitelist <- unique(c(tolower(project_vocab), user_whitelist))
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
    selectInput("sheet_selected", "Filter by sheet:", choices = sheets_rv(), selected = sheets_rv()[[1]])
  })
  
  filtered_sheet <- reactive({
    reslist <- results_list_rv()
    if (is.null(reslist) || is.null(input$sheet_selected)) return(data.frame())
    cur <- reslist[[input$sheet_selected]]
    if (is.null(cur)) return(data.frame())
    cur
  })
  
  output$preview_dt <- DT::renderDataTable({
    filtered_sheet()
  }, options = list(pageLength = 10))
  
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
