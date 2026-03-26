library(tidyverse)
library(knitr)
library(kableExtra)

# ── Chargement et encodage des variables ─────────────────────────────────────

data <- read.csv("data/Customer Churn.csv", check.names = FALSE) |>
  mutate(
    Churn            = factor(Churn, levels = c(0, 1), labels = c("No", "Yes")),
    Complains        = factor(Complains, levels = c(0, 1), labels = c("No", "Yes")),
    `Age Group`      = factor(`Age Group`, levels = 1:5, ordered = TRUE),
    `Charge  Amount` = factor(`Charge  Amount`, levels = 0:10, ordered = TRUE),
    `Tariff Plan`    = factor(`Tariff Plan`, levels = c(1, 2), labels = c("Prépayé", "Forfait")),
    Status           = factor(Status, levels = c(1, 2), labels = c("Actif", "Inactif"))
  )


# ── Dictionnaire des variables ───────────────────────────────────────────────

# str_squish() retire les espaces multiples dans les noms (ex. "Call  Failure")
noms_formates <- names(data) |>
  str_squish() |>
  str_to_title()

# FIX : class() retourne c("ordered", "factor") pour les facteurs ordonnés.
# On construit un label lisible et sans ambiguïté.
types_colonnes <- sapply(data, \(x) {
  if (is.ordered(x)) {
    "Facteur ordonné"
  } else if (is.factor(x)) {
    "Facteur"
  } else if (is.integer(x)) {
    "Entier"
  } else if (is.numeric(x)) {
    "Numérique"
  } else {
    class(x)[1]
  }
})

descriptions <- c(
  "Nombre d'appels interrompus",
  "Indicateur de plainte (0/1)",
  "Durée de l'abonnement en mois",
  "Montant facturé (ordinal 0-10)",
  "Secondes totales d'utilisation",
  "Nombre total d'appels",
  "Nombre de SMS envoyés",
  "Nombre de numéros uniques appelés",
  "Tranche d'âge (ordinal 1-5)",
  "Type de forfait",
  "Statut du compte (actif/inactif)",
  "Âge du client",
  "Valeur estimée du client",
  "Cible : désabonnement (Yes / No)"
)

dictionnaire <- data.frame(
  `Nom de la variable` = noms_formates,
  `Type` = types_colonnes,
  `Description` = descriptions,
  check.names = FALSE
)


# ── Tableau final ─────────────────────────────────────────────────────────────

tableau_presentation_donnees <- kable(
  dictionnaire,
  caption   = "Dictionnaire des variables du jeu de données",
  booktabs  = TRUE,
  align     = c("l", "c", "l"),
  row.names = FALSE
) |>
  kable_styling(
    latex_options = c("striped", "hold_position"),
    font_size     = 10
  )

rm(list = setdiff(ls(), c("data", "tableau_presentation_donnees")))
