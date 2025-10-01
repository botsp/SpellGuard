library(shiny)
library(openxlsx)
library(hunspell)
library(DT)

# Convert (row, col) to Excel cell address, e.g. (6,2) -> B6
cellLabel <- function(row, col) {
  label <- ""
  while (col > 0) {
    rem <- (col - 1) %% 26
    label <- paste0(LETTERS[rem + 1], label)
    col <- (col - rem - 1) %/% 26
  }
  paste0(label, row)
}

# Core function: spell-check over all cells, report Excel coordinates and content
sheet_results <- function(df, sheet) {
  nrow_df <- nrow(df)
  ncol_df <- ncol(df)
  if (nrow_df == 0 || ncol_df == 0) return(NULL)
  results <- list()
  for (row in seq_len(nrow_df)) {
    for (col in seq_len(ncol_df)) {
      val <- as.character(df[row, col])
      # Only spell-check cells with non-blank content containing letters
      if (!is.na(val) && nchar(trimws(val)) > 0 && grepl("[a-zA-Z]", val)) {
        miss <- hunspell(val)[[1]]
        if (length(miss) > 0) {
          excel_cell <- cellLabel(row, col)
          results[[length(results) + 1]] <- data.frame(
            ID = paste0(sheet, "_", excel_cell),
            Sheet = sheet,
            Cell = excel_cell,
            OriginalText = val,
            MisspelledWords = paste(miss, collapse = "; "),
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
      uiOutput("sheet_selector"),
      downloadButton("download", "Download Spell Check Results"),
      tags$div(
        style = "font-size: 12px; color: #7d7d7d; margin-top: 10px;",
        "Note: 'Cell' indicates the real Excel coordinate (such as B6). If the source file omits physical blank rows or columns, cell mapping may be shifted."
      )
    ),
    mainPanel(
      DT::dataTableOutput("preview_dt")
    )
  )
)

server <- function(input, output, session) {
  sheets_rv <- reactiveVal(NULL)
  all_results_rv <- reactiveVal(NULL)
  
  # When a file is uploaded, extract all sheet names and run spell check for each sheet
  observeEvent(input$file, {
    req(input$file)
    file_path <- input$file$datapath
    sheets <- getSheetNames(file_path)
    sheets_rv(sheets)
    all_results <- lapply(sheets, function(sh) {
      # Load the sheet with all empty rows/columns preserved
      df <- read.xlsx(file_path, sheet = sh, colNames = FALSE, skipEmptyRows = FALSE, skipEmptyCols = FALSE)
      sheet_results(df, sh)
    })
    # Combine all results into a single data frame
    results_df <- do.call(rbind, Filter(Negate(is.null), all_results))
    all_results_rv(results_df)
    # Set the default displayed sheet as the first one
    if (length(sheets) > 0) {
      updateSelectInput(session, "sheet_selected", selected = sheets[[1]])
    }
  })
  
  # Sheet selector UI is displayed only after file upload
  output$sheet_selector <- renderUI({
    req(sheets_rv())
    selectInput("sheet_selected", "Filter by sheet:", choices = sheets_rv(), selected = sheets_rv()[[1]])
  })
  
  # Filter results for the selected sheet only
  filtered_sheet <- reactive({
    results <- all_results_rv()
    if (is.null(results)) return(data.frame())
    if (is.null(input$sheet_selected)) return(results)
    subset(results, Sheet == input$sheet_selected)
  })
  
  # Paginated, sortable, and searchable data table in the main panel
  output$preview_dt <- DT::renderDataTable({
    filtered_sheet()
  }, options = list(pageLength = 10))
  
  # Download filtered results as Excel file
  output$download <- downloadHandler(
    filename = function() {"spell_check_results.xlsx"},
    content = function(file) {
      write.xlsx(filtered_sheet(), file)
    }
  )
}

shinyApp(ui, server)
