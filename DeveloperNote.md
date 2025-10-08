## 1. Issue1 Excel Blank Row Positioning Limitation
Summary: Excel Blank Row Positioning Limitation
When importing Excel files into R (or Python, SAS, etc.), a recurring challenge is preserving the true physical location (the actual row number in Excel) of each cell—even if there are many blank rows at the top of the sheet.

Root Cause:
Excel does not physically store entirely blank rows at the top (or the end) of a worksheet in its underlying file. When the sheet is saved, any rows that are completely empty (no values, formulas, formatting, or content) may be omitted from the file structure.

No Information to Recover:
As a result, when you load such a file with R’s openxlsx or readxl (even with all skip options turned off), those blank rows simply do not exist in the imported data frame. What appears as “row 6” in R is actually the first non-blank row in Excel—if the top five rows were entirely blank and not stored in the file, there is no metadata or marker to indicate that other rows ever existed.

Why Columns Are Different:
Excel often preserves column structure because headers typically occupy the first row, and blank columns with a header will persist in the file. That’s why it’s possible to reliably map columns (A, B, C, …) but not missing blank rows.

True Physical Row Addressing:
Unless Excel’s file was saved in a way that physically includes those blank top rows (for example, by putting a space or dummy value into each “blank” row), it is impossible for any software to reconstruct the original row numbers for cells below those omitted rows.

Best Practice (Root Solution):
If precise cell addressing (e.g., outputting “B6” for a value visually located at B6 in Excel) is required, the upstream Excel generation process must ensure blank rows are not truly empty—they must contain at least one character (such as a space) or formatting to force their inclusion in the file.
Otherwise, there is no programmatic way to determine original, “visual” row numbers for data below.

Conclusion:
This limitation is inherent to Excel’s file structure, not R code or the openxlsx/readxl packages. Any solution must be addressed at the file creation or pre-processing stage, not in data reading code.

## 2. Issue2
Implemented multi-core parallel processing for spell checking across Excel sheets or row blocks using future.apply::future_lapply or parallel::mclapply. Each sheet or row block is processed independently on separate cores, with the main thread aggregating results. This approach significantly enhances performance for large datasets by distributing computational load, maintaining scalability, and ensuring efficient spell checking with minimal overhead.

With a free Posit Cloud account limited to 1 CPU and 1GB of memory, there are no additional cores available for true parallel processing. Even when using future.apply::future_lapply or parallel::mclapply, the tasks will not run in parallel but instead execute sequentially due to the single-core limitation. The system may simulate concurrency by switching between tasks (e.g., across different sessions), but this is effectively "fake concurrency" with no actual parallel execution.
