library(shiny)
library(readxl)
library(openxlsx)
library(hunspell)

# Return Excel-style cell address like "B6"
cellLabel <- function(row, col) {
  if (length(row) != 1 || length(col) != 1) stop("Arguments must be scalar")
  if (col < 1) stop("Column number should be >= 1")
  label <- ""
  tmp_col <- col
  while (tmp_col > 0) {
    rem <- (tmp_col - 1) %% 26
    label <- paste0(LETTERS[rem + 1], label)
    tmp_col <- (tmp_col - rem - 1) %/% 26
  }
  paste0(label, row)
}

sheet_results <- function(df, sheet) {
  nrow_df <- nrow(df)
  ncol_df <- ncol(df)
  if (nrow_df == 0 || ncol_df == 0) return(NULL)
  
  # Construct original mapping for all cells
  row_idx <- seq_len(nrow_df)
  col_idx <- seq_len(ncol_df)
  coord <- expand.grid(Row = row_idx, Col = col_idx)
  # as.matrix flattens by columns: A1, A2, ..., B1, B2, ...
  coord$Text <- as.character(as.matrix(df))
  coord$Sheet <- sheet
  coord$Cell <- mapply(cellLabel, coord$Row, coord$Col)
  
  # Only keep which cells need spell check (but mapping is always to original!)
  keep_idx <- which(
    !is.na(coord$Text) &
      nchar(trimws(coord$Text)) > 0 &
      grepl("[a-zA-Z]", coord$Text)
  )
  if (length(keep_idx) == 0) return(NULL)
  miss_list <- hunspell(coord$Text[keep_idx])
  
  rows_out <- list()
  for (j in seq_along(miss_list)) {
    miss <- miss_list[[j]]
    orig_idx <- keep_idx[j]
    if (length(miss) > 0) {
      rows_out[[length(rows_out) + 1]] <- data.frame(
        ID = paste0(coord$Sheet[orig_idx], "_", coord$Cell[orig_idx]),
        Sheet = as.character(coord$Sheet[orig_idx]),
        Row = as.integer(coord$Row[orig_idx]),
        Col = as.integer(coord$Col[orig_idx]),
        Cell = as.character(coord$Cell[orig_idx]),
        OriginalText = as.character(coord$Text[orig_idx]),
        MisspelledWords = as.character(paste(miss, collapse = "; ")),
        ExcelRef = paste0(coord$Sheet[orig_idx], "!", coord$Cell[orig_idx]),
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(rows_out) == 0) return(NULL)
  do.call(rbind, rows_out)
}

ui <- fluidPage(
  titlePanel("Excel Spell Checker (Original Cell Mapping)"),
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
    sheets <- excel_sheets(file_path)
    all_results <- lapply(sheets, function(sh) {
      df <- read_excel(file_path, sheet = sh)
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
