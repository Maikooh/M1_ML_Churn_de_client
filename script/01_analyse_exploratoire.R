# Ce script réalise une analyse exploratoire des données,
# en se concentrant sur les statistiques descriptives des variables numériques.
# "data" doit déjà être chargé

library(knitr)
library(kableExtra)
library(tidyverse)

# ── Tableau des stats descriptives variables numériques ──────────────

tableau_summary <- data |>
  select(where(is.numeric)) |>
  pivot_longer(everything(), names_to = "Variable") |>
  group_by(Variable) |>
  summarise(
    Min          = min(value, na.rm = TRUE),
    Q1           = quantile(value, 0.25, na.rm = TRUE),
    Médiane      = median(value, na.rm = TRUE),
    Moyenne      = round(mean(value, na.rm = TRUE), 2),
    Q3           = quantile(value, 0.75, na.rm = TRUE),
    Max          = max(value, na.rm = TRUE),
    `Écart-type` = round(sd(value, na.rm = TRUE), 2),
    `NA (%)`     = round(mean(is.na(value)) * 100, 1)
  ) |>
  kable(
    booktabs = TRUE,
    caption  = "Statistiques descriptives des variables numériques",
    align    = c("l", rep("r", 8))
  ) |>
  kable_styling(
    latex_options = c("striped", "hold_position", "scale_down"),
    font_size     = 9
  )


# ── Tableau des stats descriptives variables catégorielles ────────────

tableau_summary_cat <- data |>
  select(where(is.factor)) |>
  pivot_longer(everything(), names_to = "Variable", values_to = "Modalite") |>
  group_by(Variable, Modalite) |>
  summarise(n = n(), .groups = "drop") |>
  group_by(Variable) |>
  mutate(
    `NA (%)` = round(mean(is.na(Modalite)) * 100, 1),
    `%`      = round(n / sum(n) * 100, 1)
  ) |>
  ungroup() |>
  arrange(Variable, desc(n)) |>
  rename(
    `Modalité` = Modalite,
    `Effectif` = n
  ) |>
  kable(
    booktabs = TRUE,
    caption  = "Statistiques descriptives des variables catégorielles",
    align    = c("l", "l", "r", "r", "r")
  ) |>
  kable_styling(
    latex_options = c("striped", "hold_position"),
    font_size     = 9
  ) |>
  collapse_rows(columns = c(1, 4), latex_hline = "major", valign = "middle")
