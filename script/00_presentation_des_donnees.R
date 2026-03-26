library(knitr)
library(kableExtra)
library(stringr)
library(tidyverse)


data <- read.csv("data/Customer Churn.csv", check.names = FALSE) |>
  mutate(
    `Churn` = factor(`Churn`, levels = c(0, 1), labels = c("No", "Yes")),
    `Complains` = factor(`Complains`, levels = c(0, 1), labels = c("No", "Yes")),
    `Age Group` = factor(`Age Group`, levels = 1:5, ordered = TRUE),
    `Charge  Amount` = factor(`Charge  Amount`, levels = 0:10, ordered = TRUE),
    `Tariff Plan` = factor(`Tariff Plan`, levels = c(1, 2), labels = c("Prépayé", "Forfait")),
    `Status` = factor(`Status`, levels = c(1, 2), labels = c("Actif", "Inactif"))
  )


# Formatage
noms_bruts <- names(data)
types_colonnes <- sapply(data, class)

noms_formates <- noms_bruts |>
  str_replace_all("\\.+", " ") |>
  str_squish() |>
  str_to_title()

# ajout des descriptions
descriptions <- c(
  "Nombre d'appels interrompus",
  "Indicateur de plainte (0/1)",
  "Durée de l'abonnement en mois",
  "Montant facturé",
  "Secondes totales d'utilisation",
  "Nombre total d'appels",
  "Nombre de SMS envoyés",
  "Nombre de numéros uniques appelés",
  "Tranche d'âge (catégoriel)",
  "Type de forfait",
  "Statut du compte (actif/inactif)",
  "Âge du client",
  "Valeur estimée du client",
  "Cible : Désabonnement (1) ou non (0)"
)

dictionnaire <- data.frame(
  `Nom de la variable` = noms_formates,
  Type = types_colonnes,
  Description = descriptions,
  check.names = FALSE
)

# Tableau final
tableau_presentation_donnees <- kable(dictionnaire,
  caption = "Dictionnaire des variables du dataframe",
  booktabs = TRUE,
  align = c("l", "c", "l"),
  row.names = FALSE
) |>
  kable_styling(
    latex_options = c("striped", "hold_position"),
    font_size = 10
  )

rm(list = setdiff(ls(), c("data", "tableau_presentation_donnees")))
