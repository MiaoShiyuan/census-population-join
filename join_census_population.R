# =============================================================================
# Join census population onto survey data by municipality name
# -----------------------------------------------------------------------------
# This script links official population figures (national census) to a survey
# dataset, keyed on prefecture + municipality name.
#
# The tricky part of this kind of linkage in Japan is that municipality names do
# not always match character-for-character across sources: a census and a survey
# may use different variant / old-form kanji for the same town
# (e.g. 鯵ヶ沢町 vs 鰺ヶ沢町). This script performs the join, reports any rows
# that fail to match, and applies a small correction table for known variants.
#
# Data note: the census data is publicly available; the survey data is not
# included here. The file/column names below are placeholders. The script runs
# end-to-end on the synthetic sample data defined at the bottom, so the full
# workflow is reproducible without any external files.
# =============================================================================

library(dplyr)

# -----------------------------------------------------------------------------
# 1. Clean raw census data
# -----------------------------------------------------------------------------
# Raw census tables ship with numeric code prefixes on the region names
# ("0105_留寿都村") and include pre-merger old place names flagged with "旧：".
# This function strips the prefixes, drops the old names, coerces population to
# numeric, and keeps one row per prefecture + municipality.
#
# Expected input columns: 都道府県 (prefecture), 地域名 (region name), 人口 (population)
clean_census <- function(census_raw) {
  census_raw %>%
    filter(!is.na(地域名), !is.na(人口)) %>%
    mutate(人口 = as.numeric(人口)) %>%
    filter(!is.na(人口)) %>%
    filter(!grepl("旧：", 地域名)) %>%                 # drop pre-merger old names
    mutate(
      都道府県 = sub("^[0-9]+_", "", 都道府県),         # "01_北海道"    -> "北海道"
      自治体名 = sub("^[0-9]+_", "", 地域名)            # "0105_留寿都村" -> "留寿都村"
    ) %>%
    distinct(都道府県, 自治体名, .keep_all = TRUE) %>%
    select(都道府県, 自治体名, 人口)
}

# -----------------------------------------------------------------------------
# 2. Known variant-character corrections
# -----------------------------------------------------------------------------
# Same municipality, different kanji across the two sources. `survey_name` is the
# spelling used in the survey; `census_name` is the spelling used in the census.
# Extend this table whenever a new mismatch shows up in the unmatched report.
variant_map <- tibble::tribble(
  ~survey_name,   ~census_name,
  "鯵ヶ沢町",     "鰺ヶ沢町",    # 鯵 vs 鰺
  "青ケ島村",     "青ヶ島村",    # ケ vs ヶ
  "梼原町",       "檮原町"       # 梼 vs 檮
)

# -----------------------------------------------------------------------------
# 3. Join population onto survey data
# -----------------------------------------------------------------------------
# Two-pass join:
#   (a) straight join on prefecture + municipality name;
#   (b) for rows still unmatched, retry via the variant map by translating the
#       survey spelling into the census spelling.
# Prints a match-rate summary and lists anything still unmatched.
join_census_population <- function(survey, census, variants = variant_map) {

  # (a) first pass
  joined <- survey %>%
    left_join(census, by = c("都道府県", "自治体名"))

  # (b) build a fix table: census population reachable via the variant spelling
  fix <- census %>%
    inner_join(variants, by = c("自治体名" = "census_name")) %>%
    select(都道府県, survey_name, 人口_fix = 人口)

  joined <- joined %>%
    left_join(fix, by = c("都道府県", "自治体名" = "survey_name")) %>%
    mutate(人口 = coalesce(人口, 人口_fix)) %>%
    select(-人口_fix)

  # report
  matched <- sum(!is.na(joined$人口))
  cat(sprintf("Matched population: %d / %d\n", matched, nrow(joined)))

  unmatched <- joined %>% filter(is.na(人口)) %>% select(都道府県, 自治体名)
  if (nrow(unmatched) > 0) {
    cat("Unmatched municipalities:\n")
    print(as.data.frame(unmatched))
  } else {
    cat("All rows matched.\n")
  }

  joined
}

# =============================================================================
# Demo on synthetic data (runs standalone, no external files needed)
# =============================================================================
if (sys.nframe() == 0) {

  # Synthetic "raw" census sample, mimicking the layout of a real census file:
  # code-prefixed names, an "旧：" old name to be dropped, census-side spellings.
  census_raw_demo <- tibble::tribble(
    ~都道府県,      ~地域名,           ~人口,
    "01_北海道",   "0105_留寿都村",   "1817",
    "02_青森県",   "0203_鰺ヶ沢町",   "9522",     # census spelling: 鰺
    "13_東京都",   "1340_青ヶ島村",   "169",      # census spelling: ヶ
    "39_高知県",   "3941_檮原町",     "3315",     # census spelling: 檮
    "13_東京都",   "旧：合併前町",    "5000",     # pre-merger old name -> dropped
    "01_北海道",   "0100_札幌市",     "1973395"
  )

  # Synthetic survey sample, using the survey-side spellings (the variants).
  survey_demo <- tibble::tribble(
    ~都道府県,   ~自治体名,     ~団体コード,
    "北海道",   "留寿都村",    "01105",
    "青森県",   "鯵ヶ沢町",    "02321",           # survey spelling: 鯵 (variant)
    "東京都",   "青ケ島村",    "13402",           # survey spelling: ケ (variant)
    "高知県",   "梼原町",      "39405",           # survey spelling: 梼 (variant)
    "北海道",   "札幌市",      "01100"
  )

  census_demo <- clean_census(census_raw_demo)
  result <- join_census_population(survey_demo, census_demo)

  cat("\nResult:\n")
  print(as.data.frame(result))
}

# -----------------------------------------------------------------------------
# Real usage (uncomment and point to your own files)
# -----------------------------------------------------------------------------
# library(readxl)
# library(openxlsx)
#
# survey     <- read_excel("survey_data.xlsx", sheet = "your_sheet")
#
# # Column positions (5, 7, 8) depend on the specific census file layout;
# # adjust to match your file, then rename to the expected column names.
# census_raw <- read_excel("census_population.xlsx", sheet = "your_sheet", skip = 14) %>%
#   select(都道府県 = 5, 地域名 = 7, 人口 = 8)
# census     <- clean_census(census_raw)
#
# result <- join_census_population(survey, census)
# write.xlsx(result, "survey_with_population.xlsx", overwrite = TRUE)
