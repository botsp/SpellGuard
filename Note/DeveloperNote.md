## 1. Known Issues/Limitations
### 1.1 Excel Blank Row Positioning Limitation
Summary: Excel Blank Row Positioning Limitation
When importing Excel files into R, a recurring challenge is preserving the true physical location (the actual row number in Excel) of each cell—even if there are many blank rows at the top of the sheet.

Root Cause:
Excel does not physically store entirely blank rows at the top (or the end) of a worksheet in its underlying file. When the sheet is saved, any rows that are completely empty (no values, formulas, formatting, or content) may be omitted from the file structure.

No Information to Recover:
As a result, when you load such a file with R’s openxlsx or readxl (even with all skip options turned off), those blank rows simply do not exist in the imported data frame. What appears as “row 6” in R is actually the first non-blank row in Excel—if the top five rows were entirely blank and not stored in the file, there is no metadata or marker to indicate that other rows ever existed.

True Physical Row Addressing:
Unless Excel’s file was saved in a way that physically includes those blank top rows (for example, by putting a space or dummy value into each “blank” row), it is impossible for any software to reconstruct the original row numbers for cells below those omitted rows.

Best Practice (Root Solution):
If precise cell addressing (e.g., outputting “B6” for a value visually located at B6 in Excel) is required, the upstream Excel generation process must ensure blank rows are not truly empty—they must contain at least one character (such as a space) or formatting to force their inclusion in the file.
Otherwise, there is no programmatic way to determine original, “visual” row numbers for data below.

Conclusion:
This limitation is inherent to Excel’s file structure, not R code or the openxlsx/readxl packages. Any solution must be addressed at the file creation or pre-processing stage, not in data reading code.

### 1.2 Multi-core parallel processing
Implemented multi-core parallel processing for spell checking across Excel sheets or row blocks using future.apply::future_lapply, which significantly increases the processing speed (for example, with a free connect.posit.cloud account, Resources are increased to 4GB memory and 2 CPUs. Multi-core processing can improve speed by 30–40%). However, this approach cannot utilize progress bars that rely on the main thread, resulting in the loss of a key feature. Therefore, single-threaded processing is used instead.
(Whenever possible, use gerl instead of sapply, as it can provide a slight improvement in speed.)

### 1.3 hunspell Case Sensitivity Rules
Most basic English words are accepted by `hunspell` in any letter case (sentence case, all capitals, all lowercase).
However, proper nouns are handled strictly according to English conventions—sentence case (capitalized) and all uppercase are usually acceptable, while all lowercase is not (which aligns with business and language standards).
````
hunspell_check(c("JANUARY", "January", "january")) # [1] TRUE  TRUE FALSE
````

### 1.4 Core process of `hunspell`
Attempts have been made to extract and convert words to lower or upper case before performing uniqueness checks. This approach can reduce the number of hunspell calls, improve speed, and broaden the range of recognized words. However, it inevitably leads to “false negatives,” which affects detection accuracy. There were also attempts to implement a lazy double validation (i.e., checking both lower/upper case and the original text), but this did not completely solve the false negatives and instead slowed down processing. Therefore, the core process is to detect using the original text directly, and whitelist matching is also done using the original text, without any case conversion.


