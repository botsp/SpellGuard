library(shiny)
library(openxlsx)
library(hunspell)
library(DT)
library(stringr)

cellLabel <- function(row, col) {
  label <- ""
  while (col > 0) {
    rem <- (col - 1) %% 26
    label <- paste0(LETTERS[rem + 1], label)
    col <- (col - rem - 1) %/% 26
  }
  paste0(label, row)
}

# Helper: is this word ALL upper-case English letters (ignores any symbols/digits)
is_all_upper_word <- function(word) {
  txt <- gsub("[^A-Za-z]", "", word)
  nzchar(txt) && txt == toupper(txt)
}

sheet_results <- function(df, sheet, ignore_upper = TRUE) {
  nrow_df <- nrow(df)
  ncol_df <- ncol(df)
  if (nrow_df == 0 || ncol_df == 0) return(NULL)
  results <- list()
  for (row in seq_len(nrow_df)) {
    for (col in seq_len(ncol_df)) {
      val <- as.character(df[row, col])
      if (!is.na(val) && nchar(trimws(val)) > 0 && grepl("[a-zA-Z]", val)) {
        # Split into words (by non-word boundary)
        words <- unlist(str_extract_all(val, "\\b[\\w'-]+\\b"))
        # Filter out ALL UPPERCASE words if needed
        check_words <- if (ignore_upper) {
          words[!sapply(words, is_all_upper_word)]
        } else {
          words
        }
        # Only spell-check the remaining words
        misspelled <- unique(unlist(hunspell(check_words)))
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
  
  observeEvent(input$file, {
    file_path <- input$file$datapath
    sheets <- getSheetNames(file_path)
    sheets_rv(sheets)
    if (length(sheets) > 0) {
      updateSelectInput(session, "sheet_selected", choices = sheets, selected = sheets[[1]])
    }
  })
  
  output$sheet_selector <- renderUI({
    req(sheets_rv())
    selectInput("sheet_selected", "Filter by sheet:", choices = sheets_rv(), selected = sheets_rv()[[1]])
  })
  
  spell_results <- reactive({
    req(input$file)
    sheets <- sheets_rv()
    if (is.null(sheets)) return(data.frame())
    all_results <- lapply(sheets, function(sh) {
      df <- read.xlsx(input$file$datapath, sheet = sh, colNames = FALSE, skipEmptyRows = FALSE, skipEmptyCols = FALSE)
      sheet_results(df, sh, ignore_upper = input$ignore_uppercase)
    })
    results <- Filter(Negate(is.null), all_results)
    if (length(results) == 0) {
      data.frame(
        ID = character(),
        Sheet = character(),
        Cell = character(),
        OriginalText = character(),
        MisspelledWords = character(),
        stringsAsFactors = FALSE
      )
    } else {
      do.call(rbind, results)
    }
  })
  
  filtered_sheet <- reactive({
    results <- spell_results()
    if (is.null(results)) return(data.frame())
    if (is.null(input$sheet_selected)) return(results)
    subset(results, Sheet == input$sheet_selected)
  })
  
  output$preview_dt <- DT::renderDataTable({
    filtered_sheet()
  }, options = list(pageLength = 10))
  
  output$download <- downloadHandler(
    filename = function() {"spell_check_results.xlsx"},
    content = function(file) {
      write.xlsx(spell_results(), file)
    }
  )
}

shinyApp(ui, server)
