-- MySQL CSV Import, Export, and Cleaning Assignment
-- Requires MySQL 8.0+ for ROW_NUMBER(). Run sections in order.
-- Keep the imported table as a backup; build a separate clean table.

CREATE DATABASE IF NOT EXISTS csv_cleaning_assignment;
USE csv_cleaning_assignment;

DROP TABLE IF EXISTS customers_clean;
DROP TABLE IF EXISTS customers_raw;

-- Import every CSV field as text first so messy values do not fail type conversion.
CREATE TABLE customers_raw (
    record_id VARCHAR(20),
    customer_id VARCHAR(20),
    customer_name VARCHAR(200),
    email VARCHAR(255),
    age VARCHAR(30),
    city VARCHAR(100),
    signup_date VARCHAR(30),
    annual_income VARCHAR(40),
    membership VARCHAR(40),
    last_purchase_date VARCHAR(30),
    notes TEXT
);

-- Check MySQL's permitted server-side directory.
SHOW VARIABLES LIKE 'secure_file_priv';

-- CLIENT-SIDE import: edit this path to where customers_raw.csv is saved.
-- LOCAL may need to be enabled by both the MySQL client and server.
LOAD DATA LOCAL INFILE 'C:/PATH/TO/customers_raw.csv'
INTO TABLE customers_raw
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- SERVER-SIDE alternative: copy the file into the secure_file_priv folder,
-- then use LOAD DATA INFILE (remove LOCAL) and that server-visible path.
-- LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/customers_raw.csv'
-- INTO TABLE customers_raw
-- CHARACTER SET utf8mb4
-- FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
-- LINES TERMINATED BY '\r\n'
-- IGNORE 1 LINES;

-- 1. Import checks and quality profiling.
SELECT COUNT(*) AS imported_rows FROM customers_raw;
SELECT * FROM customers_raw LIMIT 10;
SELECT COUNT(*) AS blank_email_rows
FROM customers_raw WHERE email IS NULL OR TRIM(email) = '';

-- Duplicate email groups after normalization (ignore blanks).
SELECT LOWER(TRIM(email)) AS normalized_email, COUNT(*) AS copies
FROM customers_raw
WHERE email IS NOT NULL AND TRIM(email) <> ''
GROUP BY LOWER(TRIM(email))
HAVING COUNT(*) > 1
ORDER BY copies DESC, normalized_email
LIMIT 20;

-- 2. Number duplicates; the smallest record_id is retained.
SELECT record_id, customer_id, email,
       ROW_NUMBER() OVER (
           PARTITION BY LOWER(TRIM(email))
           ORDER BY CAST(record_id AS UNSIGNED)
       ) AS row_num
FROM customers_raw
WHERE email IS NOT NULL AND TRIM(email) <> ''
ORDER BY LOWER(TRIM(email)), CAST(record_id AS UNSIGNED)
LIMIT 50;

-- 3. Clean text and convert invalid values to NULL. Deduplicate on normalized
-- nonblank email; keep rows with missing email so they can be reviewed separately.
CREATE TABLE customers_clean (
    record_id INT NOT NULL,
    customer_id INT,
    customer_name VARCHAR(200),
    email VARCHAR(255),
    age TINYINT UNSIGNED,
    city VARCHAR(100),
    signup_date DATE,
    annual_income DECIMAL(12,2),
    membership VARCHAR(40),
    last_purchase_date DATE,
    notes TEXT,
    PRIMARY KEY (record_id),
    INDEX idx_customers_clean_email (email)
);

INSERT INTO customers_clean
    (record_id, customer_id, customer_name, email, age, city,
     signup_date, annual_income, membership, last_purchase_date, notes)
SELECT
    CAST(record_id AS UNSIGNED),
    CAST(NULLIF(TRIM(customer_id), '') AS UNSIGNED),
    NULLIF(CONCAT(UPPER(LEFT(LOWER(TRIM(customer_name)), 1)),
                  SUBSTRING(LOWER(TRIM(customer_name)), 2)), ''),
    NULLIF(LOWER(TRIM(email)), ''),
    CASE WHEN TRIM(age) REGEXP '^[0-9]{1,3}$'
              AND CAST(TRIM(age) AS UNSIGNED) BETWEEN 0 AND 120
         THEN CAST(TRIM(age) AS UNSIGNED) ELSE NULL END,
    NULLIF(CONCAT(UPPER(LEFT(LOWER(TRIM(city)), 1)),
                  SUBSTRING(LOWER(TRIM(city)), 2)), ''),
    CASE WHEN TRIM(signup_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
         THEN STR_TO_DATE(TRIM(signup_date), '%Y-%m-%d') ELSE NULL END,
    CASE WHEN TRIM(annual_income) REGEXP '^[0-9]+(\\.[0-9]{1,2})?$'
         THEN CAST(TRIM(annual_income) AS DECIMAL(12,2)) ELSE NULL END,
    NULLIF(CONCAT(UPPER(LEFT(LOWER(TRIM(membership)), 1)),
                  SUBSTRING(LOWER(TRIM(membership)), 2)), ''),
    CASE WHEN TRIM(last_purchase_date) REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
         THEN STR_TO_DATE(TRIM(last_purchase_date), '%Y-%m-%d') ELSE NULL END,
    NULLIF(TRIM(notes), '')
FROM (
    SELECT r.*,
           ROW_NUMBER() OVER (
               PARTITION BY NULLIF(LOWER(TRIM(email)), ''),
                            CASE WHEN email IS NULL OR TRIM(email) = ''
                                 THEN CAST(record_id AS UNSIGNED) ELSE NULL END
               ORDER BY CAST(record_id AS UNSIGNED)
           ) AS row_num
    FROM customers_raw AS r
) AS ranked
WHERE ranked.row_num = 1;

-- 4. Validate cleaned output and confirm no repeated nonblank normalized emails.
SELECT COUNT(*) AS cleaned_rows FROM customers_clean;
SELECT COUNT(*) AS remaining_duplicate_email_groups
FROM (
    SELECT email FROM customers_clean
    WHERE email IS NOT NULL AND TRIM(email) <> ''
    GROUP BY email HAVING COUNT(*) > 1
) AS duplicate_groups;
SELECT COUNT(*) AS rows_with_invalid_or_missing_age
FROM customers_clean WHERE age IS NULL;
SELECT * FROM customers_clean ORDER BY record_id LIMIT 10;

-- 5. Export: use a new filename inside secure_file_priv. MySQL will not overwrite.
-- This UNION ALL writes a header row, followed by the data rows.
SELECT 'record_id','customer_id','customer_name','email','age','city',
       'signup_date','annual_income','membership','last_purchase_date','notes'
UNION ALL
SELECT CAST(record_id AS CHAR), CAST(customer_id AS CHAR), customer_name,
       email, CAST(age AS CHAR), city,
       IFNULL(DATE_FORMAT(signup_date, '%Y-%m-%d'), ''),
       IFNULL(CAST(annual_income AS CHAR), ''), membership,
       IFNULL(DATE_FORMAT(last_purchase_date, '%Y-%m-%d'), ''), notes
FROM customers_clean
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/customers_clean_export.csv'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\r\n';

-- Verify the clean table is preserved and ready for another CSV export.
SHOW TABLES;


