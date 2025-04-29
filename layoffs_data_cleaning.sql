# Data Cleaning

# View original data
SELECT * 
FROM layoffs;

# 1. Remove duplicates
# 2. Standardize the data
# 3. Handle null or blank values
# 4. Remove any unnecessary columns

# Create staging table
CREATE TABLE layoffs_staging
LIKE layoffs;

# View staging table
SELECT * 
FROM layoffs_staging;

# Insert data into staging table
INSERT layoffs_staging
SELECT * 
FROM layoffs;

# View updated staging table
SELECT * 
FROM layoffs;

# Add row numbers to find duplicates
SELECT *,
  ROW_NUMBER() OVER(PARTITION BY company, location, industry, total_laid_off, 
                    percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging;

# Identify duplicate records
WITH duplicate_cte AS (
  SELECT *,
    ROW_NUMBER() OVER(PARTITION BY company, location, industry, total_laid_off, 
                      percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
  FROM layoffs_staging
)
SELECT *
FROM duplicate_cte
WHERE row_num > 1;

# Check sample record
SELECT * 
FROM layoffs_staging
WHERE company = 'Yahoo';

# Create another staging table with row_num column
CREATE TABLE layoffs_staging2 (
  company TEXT,
  location TEXT,
  industry TEXT,
  total_laid_off INT DEFAULT NULL,
  percentage_laid_off TEXT,
  `date` TEXT,
  stage TEXT,
  country TEXT,
  funds_raised_millions INT DEFAULT NULL,
  row_num INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

# View second staging table
SELECT * 
FROM layoffs_staging2;

# Insert data with row numbers
INSERT INTO layoffs_staging2
SELECT *,
  ROW_NUMBER() OVER(PARTITION BY company, location, industry, total_laid_off, 
                    percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging;

# Remove duplicate records
DELETE
FROM layoffs_staging2
WHERE row_num > 1;

# Standardize the data

# Trim whitespace from company names
SELECT company, TRIM(company)
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET company = TRIM(company);

# Clean industry names
SELECT *
FROM layoffs_staging2
WHERE industry LIKE 'Crypto%';

UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

# Clean country names
SELECT DISTINCT country
FROM layoffs_staging2
ORDER BY 1;

UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

# Convert date format
SELECT `date`, STR_TO_DATE(`date`, '%m/%d/%Y')
FROM layoffs_staging2;

UPDATE layoffs_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

# Handle null values

# Records with null values for both layoffs and percentage
SELECT *
FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

# Records with null or empty industry
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL
   OR industry = '';

# Sample check for company with missing industry
SELECT *
FROM layoffs_staging2
WHERE company LIKE 'Bally%';

# Use self-join to infer missing industry from similar records
SELECT t1.industry, t2.industry
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2
  ON t1.company = t2.company
 AND t1.location = t2.location
WHERE (t1.industry IS NULL OR t1.industry = '')
  AND t2.industry IS NOT NULL;

# Set blank industry values to NULL
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';

# Update missing industries from matching records
UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
  ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

# Delete rows with no layoff info
DELETE
FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

# Drop row_num column after de-duplication
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

# Final cleaned data
SELECT *
FROM layoffs_staging2;
