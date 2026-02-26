library(knitr)
library(kableExtra)
library(stringr)


data <- read.csv("data/Customer Churn.csv")


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