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
      ),
	  tags$div(
        style = "font-size:12px; color:#888; margin-bottom:12px;",
        paste("Shiny.app version:", ver$shinyapp_version,
              ", Last deployed:", ver$last_deployed_at,
              ", Git Ccmmit:", ver$commit)
      )
    ),
    mainPanel
      DT::dataTableOutput("preview_dt"),
      textOutput("no_error_reminder")
    )
  )
)
