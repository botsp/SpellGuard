## SpellGuard
This project is a web-based Excel spell-checking tool (deployed at [https://connect.posit.cloud/](https://connect.posit.cloud/)), built with the R Shiny framework. It supports batch spell-checking across multiple sheets and allows users to filter and review results by individual sheet. Key features and processing logic are as follows:

### Core Spell-Checking Functionality
- Utilizes the `hunspell` package to perform English spell checks on the content of Excel cells.
- Data Processing and Validation Workflow
- Automatically extracts English words from each cell, including splitting compound terms joined by underscores or hyphens.
- Skips all fully uppercase words by default to avoid false positives from variable names, acronyms, and domain-specific code.
- Compares candidate words against a comprehensive built-in whitelist; any matches are excluded from further checking.
- The remaining words are checked with hunspell for potential spelling errors.

### Rich and Extensible Whitelist Mechanism
The integrated whitelist covers `SDTM Terminology_20250926.xlsx`, `ADaM Terminology_20250926.xlsx`, `SDTMIG_v3.4.xlsx`/`ADaMIG_v1.3.xlsx` metadata files, and client-specific terms, ensuring relevance to CDISC data and client's project contexts. Please see details at [Whitlist.md](https://github.com/botsp/SpellGuard/blob/main/Whitelist.md).

### User Customization and Result Management
- Users may add custom study-level whitelist entries directly via the application interface.
- Spell-check results may be exported as Excel files for easy review and archiving.
------------------------
Please visit the live app here: [SpellGuard](https://0199a26b-b85f-0382-24f5-39903576f995.share.connect.posit.cloud/).

![SpellGuard](https://github.com/user-attachments/assets/54f25edd-8e97-43f2-b548-1ffb9e19013b)
