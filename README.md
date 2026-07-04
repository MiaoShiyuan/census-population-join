# Linking census population to survey data by municipality name

An R utility for joining official census population figures onto a survey
dataset, keyed on **prefecture + municipality name**.

## Why this is not trivial

Japanese municipality names do not always match character-for-character across
data sources. The same town can appear with different variant or old-form kanji
in a census versus a survey — for example `鯵ヶ沢町` vs `鰺ヶ沢町`. A naive join
silently drops these rows. This script handles them explicitly.

## What it does

- **`clean_census()`** — strips code prefixes from region names
  (`0105_留寿都村` → `留寿都村`), drops pre-merger old place names (`旧：…`),
  coerces population to numeric, and de-duplicates.
- **`join_census_population()`** — a two-pass join: a straight name match first,
  then a retry through a variant-character correction table for the rows that
  didn't match. It prints a match-rate summary and lists anything unmatched so
  you can extend the correction table.

## Data

The census data is publicly available. **No real survey data is included.** File
and column names in the script are placeholders. The script runs end-to-end on
the synthetic sample data defined at the bottom of the file, so you can see the
full workflow without any external files.

## Usage

```r
source("join_census_population.R")   # runs the built-in demo
```

To use with your own data, see the commented "Real usage" block at the end of
the script.

## Requirements

R with `dplyr` (and `readxl` / `openxlsx` only if you read from and write to
Excel).
