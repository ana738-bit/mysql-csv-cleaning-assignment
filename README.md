# MySQL CSV Import, Export, and Data Cleaning Assignment

This project demonstrates CSV import/export, data profiling, standardization, and duplicate handling in MySQL using a **synthetic 10,000-row customer dataset**. It follows the topics in the course note: `LOAD DATA INFILE`, `SELECT ... INTO OUTFILE`, `GROUP BY` / `HAVING`, and `ROW_NUMBER()`.

## Files

- `customers_raw.csv` — 10,000 source rows with intentionally introduced quality issues.
- `customers_clean.csv` — reproducibly cleaned and deduplicated result.
- `generate_dataset.py` — regenerates both CSV files from a fixed random seed.
- `sql/assignment.sql` — MySQL 8.0+ schema, CSV import, profiling, cleaning, deduplication, validation, and export examples.

## Dataset columns

`record_id` uniquely identifies each input row. `customer_id` identifies the underlying synthetic customer and is repeated in some rows to make duplicate detection meaningful. Other columns are `customer_name`, `email`, `age`, `city`, `signup_date`, `annual_income`, `membership`, `last_purchase_date`, and `notes`.

The raw file deliberately contains repeated customer IDs/emails, mixed capitalization and extra spaces, blank fields, invalid ages, inconsistent membership labels, and quoted notes containing commas. All records are fictional.

## Run the generator

From this folder:

```powershell
python generate_dataset.py
```

This overwrites the two generated CSVs in the current folder. The random seed is fixed, so the output is reproducible.

## Run the MySQL exercise

1. Use MySQL 8.0 or later and open `sql/assignment.sql` in MySQL Workbench or MySQL Shell.
2. Run the database and table setup sections.
3. Edit the `LOAD DATA LOCAL INFILE` path to the full path of `customers_raw.csv`. If local loading is disabled in your MySQL setup, use the server-side `LOAD DATA INFILE` option described in the SQL comments and put the CSV inside the folder returned by `SHOW VARIABLES LIKE 'secure_file_priv';`.
4. Run the profiling queries and review the duplicate groups before building the cleaned table.
5. Run the cleaning and validation sections. The script keeps one row per nonblank normalized email, preferring the smallest `record_id`; rows with missing email remain available for review rather than being collapsed into one group.
6. For export, use the `SELECT ... INTO OUTFILE` example with a new filename in the allowed server folder. MySQL does not overwrite existing output files. Alternatively use Workbench's table export wizard to save `customers_clean` as a headered CSV.

`LOCAL` reads the file from the client computer and may require local-infile support in both the MySQL client and server. Server-side `INFILE` reads from the MySQL server and is limited by `secure_file_priv` and file privileges. Keep the field delimiter, quote character, and line ending consistent between export and import.

## Expected result

The raw file contains exactly 10,000 data rows plus its header. The cleaned file contains fewer rows because repeated nonblank emails are reduced to one record, text fields are normalized, and invalid/missing values are represented as blank CSV fields. Re-running the generator recreates the same files.

## Important

The dataset is synthetic and intended for practice only. The SQL file previews duplicate groups and builds a separate cleaned table instead of deleting from the raw import, so the original data stays available for comparison.
