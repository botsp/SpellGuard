library(shiny)
library(openxlsx)
library(hunspell)
library(DT)
library(stringr)

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

# Spell-check for one Excel sheet
sheet_results <- function(df, sheet, ignore_upper = TRUE, whitelist = character()) {
  nrow_df <- nrow(df)
  ncol_df <- ncol(df)
  if (nrow_df == 0 || ncol_df == 0) return(NULL)
  results <- list()
  for (row in seq_len(nrow_df)) {
    for (col in seq_len(ncol_df)) {
      val <- as.character(df[row, col])
      # Skip empty or non-alphabetic cells
      if (!is.na(val) && nchar(trimws(val)) > 0 && grepl("[a-zA-Z]", val)) {
        # Split cell into words (includes letter, number, ' and -)
        words <- unlist(str_extract_all(val, "\\b[\\w'-]+\\b"))
        # Optionally ignore ALL UPPER words per user setting
        check_words <- if (ignore_upper) {
          words[!sapply(words, is_all_upper_word)]
        } else {
          words
        }
        # Remove whitelist words in a case-insensitive way
        check_words <- check_words[!tolower(check_words) %in% whitelist]
        # Continue if there are words to check
        if (length(check_words) > 0) {
          misspelled <- unique(unlist(hunspell(check_words)))
          # Also remove whitelist words from results
          misspelled <- setdiff(misspelled, whitelist)
          if (length(misspelled) > 0) {
            excel_cell <- cellLabel(row, col)
            results[[length(results) + 1]] <- data.frame(
              ID = paste0(sheet, "_", excel_cell),
              Sheet = sheet,
              Cell = excel_cell,
              OriginalText = val,
              MisspelledWords = paste(misspelled, collapse = "; "),
              stringsAsFactors = FALSE
            )
          }
        }
      }
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
      checkboxInput("ignore_uppercase", label = "Ignore ALL UPPERCASE words", value = TRUE),
      uiOutput("sheet_selector"),
      textAreaInput(
        "whitelist_words",
        label = "Whitelist Words (one per line, comma, space or semicolon separated):",
        value = "",
        rows = 2
      ),
      downloadButton("download", "Download Spell Check Results"),
      tags$div(
        style = "font-size: 12px; color: #7d7d7d; margin-top: 10px;",
        "Note: 'Cell' indicates the true Excel coordinate (such as B6). If the source file omits physical blank rows or columns, cell mapping may be shifted."
      )
    ),
    mainPanel(
      DT::dataTableOutput("preview_dt")
    )
  )
)

server <- function(input, output, session) {
  
  sheets_rv <- reactiveVal(NULL)
  results_list_rv <- reactiveVal(NULL)
  
  # On file upload, run spell-check for all sheets and store as a named list
  observeEvent(input$file, {
    file_path <- input$file$datapath
    sheets <- getSheetNames(file_path)
    sheets_rv(sheets)
    if (length(sheets) > 0) {
      updateSelectInput(session, "sheet_selected", choices = sheets, selected = sheets[[1]])
    }
    whitelist <- unique(tolower(unlist(strsplit(input$whitelist_words, "[,;\n\r\t ]+"))))
    whitelist <- whitelist[nzchar(whitelist)]
    res_list <- lapply(sheets, function(sh) {
      df <- read.xlsx(file_path, sheet = sh, colNames = FALSE, skipEmptyRows = FALSE, skipEmptyCols = FALSE)
      sheet_results(df, sh, ignore_upper = input$ignore_uppercase, whitelist = whitelist)
    })
    names(res_list) <- sheets
    results_list_rv(res_list)
  })
  
  # Re-check all sheets if "ignore uppercase" or whitelist changes
  observeEvent(list(input$ignore_uppercase, input$whitelist_words), {
    req(input$file)
    file_path <- input$file$datapath
    sheets <- sheets_rv()
    if (is.null(sheets)) return()
    whitelist <- unique(tolower(unlist(strsplit(input$whitelist_words, "[,;\n\r\t ]+"))))
    whitelist <- whitelist[nzchar(whitelist)]
    res_list <- lapply(sheets, function(sh) {
      df <- read.xlsx(file_path, sheet = sh, colNames = FALSE, skipEmptyRows = FALSE, skipEmptyCols = FALSE)
      sheet_results(df, sh, ignore_upper = input$ignore_uppercase, whitelist = whitelist)
    })
    names(res_list) <- sheets
    results_list_rv(res_list)
  })
  
  # Update sheet selector for sidebar
  output$sheet_selector <- renderUI({
    req(sheets_rv())
    selectInput("sheet_selected", "Filter by sheet:", choices = sheets_rv(), selected = sheets_rv()[[1]])
  })
  
  # Main Table: Only show results for the selected sheet
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
  
  # Download all sheets' results as one combined Excel sheet
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
