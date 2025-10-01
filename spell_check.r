library(shiny)
library(openxlsx)
library(hunspell)

cellLabel <- function(row, col) {
  label <- ""
  while (col > 0) {
    rem <- (col - 1) %% 26
    label <- paste0(LETTERS[rem + 1], label)
    col <- (col - rem - 1) %/% 26
  }
  paste0(label, row)
}

sheet_results <- function(df, sheet) {
  nrow_df <- nrow(df)
  ncol_df <- ncol(df)
  if (nrow_df == 0 || ncol_df == 0) return(NULL)
  
  results <- list()
  for (row in seq_len(nrow_df)) {
    for (col in seq_len(ncol_df)) {
      val <- as.character(df[row, col])
      if (!is.na(val) && nchar(trimws(val)) > 0 && grepl("[a-zA-Z]", val)) {
        miss <- hunspell(val)[[1]]
        if (length(miss) > 0) {
          excel_cell <- cellLabel(row, col) # row = Excel row #
          results[[length(results) + 1]] <- data.frame(
            ID = paste0(sheet, "_", excel_cell),
            Sheet = sheet,
            Row = row,
            Col = col,
            Cell = excel_cell,
            OriginalText = val,
            MisspelledWords = paste(miss, collapse = "; "),
            ExcelRef = paste0(sheet, "!", excel_cell),
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
  titlePanel("Excel Spell Checker (Preserve True Row/Col Address)"),
  sidebarLayout(
    sidebarPanel(
      fileInput("file", "Upload Excel File (.xlsx)"),
      downloadButton("download", "Download Spell Check Results")
    ),
    mainPanel(
      tableOutput("preview")
    )
  )
)

server <- function(input, output, session) {
  spell_results <- reactive({
    req(input$file)
    file_path <- input$file$datapath
    sheets <- getSheetNames(file_path)
    all_results <- lapply(sheets, function(sh) {
      # Preserve all structure and blank/empty cells
      df <- read.xlsx(file_path, sheet = sh, colNames = FALSE, skipEmptyRows = FALSE, skipEmptyCols = FALSE)
      sheet_results(df, sh)
    })
    results <- Filter(Negate(is.null), all_results)
    if (length(results) == 0) {
      data.frame(
        ID = character(),
        Sheet = character(),
        Row = integer(),
        Col = integer(),
        Cell = character(),
        OriginalText = character(),
        MisspelledWords = character(),
        ExcelRef = character(),
        stringsAsFactors = FALSE
      )
    } else {
      do.call(rbind, results)
    }
  })
  output$preview <- renderTable({
    head(spell_results(), 10)
  })
  output$download <- downloadHandler(
    filename = function() {"spell_check_results.xlsx"},
    content = function(file) {
      write.xlsx(spell_results(), file)
    }
  )
}

shinyApp(ui, server)
