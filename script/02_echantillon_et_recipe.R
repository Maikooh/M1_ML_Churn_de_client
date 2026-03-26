# Ce script prépare les données pour la modélisation :
#   - séparation train / test stratifiée
#   - validation croisée stratifiée
#   - recettes de préprocessing différenciées par famille de modèles
#
# Référence méthodologique : https://www.tmwr.org/pre-proc-table.html
#
# Prérequis : "data" doit être chargé via 00_presentation_des_donnees.R
#
# Objets exportés :
#   churn_split, train_data, test_data, churn_folds
#   recipe_tree, recipe_xgb, recipe_distance

library(tidymodels)
library(themis) # step_smote(), step_smotenc()

set.seed(2026)


# ── 1. Split train / test ────────────────────────────────────────────────────
#
# Stratification sur Churn pour préserver les proportions de la classe
# minoritaire (~16 %) dans les deux ensembles.

churn_split <- initial_split(data, prop = 0.80, strata = Churn)

train_data <- training(churn_split)
test_data <- testing(churn_split)


# ── 2. Validation croisée ────────────────────────────────────────────────────
#
# 10 folds stratifiés sur le train set uniquement.
# La stratification garantit ~16 % de Churn = Yes dans chaque fold.

churn_folds <- vfold_cv(train_data, v = 10, strata = Churn)


# ── 3. Recettes de préprocessing ─────────────────────────────────────────────
#
# On définit une recette par famille de modèles plutôt qu'une recette unique.
# Chaque famille a des exigences différentes (cf. tmwr.org/pre-proc-table) :
#
#   Arbres      -> pas de normalisation, pas de dummies (ranger gère les facteurs
#                 nativement et fait de meilleurs splits sur eux)
#   XGBoost    -> dummies one-hot obligatoires (attend uniquement du numérique)
#   Distance    -> normalisation obligatoire (KNN et SVM sont sensibles aux
#                 échelles), dummies pour encoder les catégorielles
#
# Le déséquilibre (~16 % Churn) est traité par SMOTE dans chaque recette.
# SMOTE est toujours en dernière étape pour ne générer des observations
# synthétiques que sur le fold d'analyse, jamais sur le fold d'évaluation


# 3.1 Recipe arbres (Random Forest, Bagging, Decision Tree) ------------------
#
# FIX : l'ancienne version appliquait step_dummy() avant step_smote(), ce qui
# forçait ranger à travailler sur des variables dummifiées alors qu'il gère
# mieux les facteurs en natif. On utilise step_smotenc() (SMOTE pour données
# mixtes numériques + catégorielles) qui n'exige pas de dummification préalable.

recipe_tree <- recipe(Churn ~ ., data = train_data) |>
  step_impute_median(all_numeric_predictors()) |>
  step_impute_mode(all_nominal_predictors()) |>
  # Pas de step_zv() : inutile pour les arbres (× dans tmwr.org/pre-proc-table).
  # Les splits binaires ignorent naturellement les colonnes constantes.
  step_smotenc(Churn) # gère les prédicteurs mixtes (num + factor)


# 3.2 Recipe XGBoost ----------------------------------------------------------
#
# one_hot = TRUE : XGBoost attend des matrices numériques sans référence
# implicite. Le encodage one-hot évite tout biais dû à l'ordre des niveaux.
# step_zv() après step_dummy() supprime les colonnes constantes potentiellement
# créées par des modalités rares.

recipe_xgb <- recipe(Churn ~ ., data = train_data) |>
  step_impute_median(all_numeric_predictors()) |>
  step_impute_mode(all_nominal_predictors()) |>
  step_dummy(all_nominal_predictors(), one_hot = TRUE) |>
  step_zv(all_predictors()) |>
  step_smote(Churn)


# 3.3 Recipe distance (KNN, SVM linéaire, SVM RBF) ----------------------------
#
# step_normalize() : indispensable pour KNN (distance euclidienne) et SVM
# (maximisation de la marge). Sans normalisation, les variables avec de grandes
# plages (ex. "Seconds of Use") domineraient le calcul de distance.
# La normalisation est appliquée AVANT step_smote() : les points synthétiques
# sont ainsi interpolés dans l'espace normalisé, ce qui est plus cohérent.

recipe_distance <- recipe(Churn ~ ., data = train_data) |>
  step_impute_median(all_numeric_predictors()) |>
  step_impute_mode(all_nominal_predictors()) |>
  step_dummy(all_nominal_predictors()) |>
  step_zv(all_predictors()) |>
  step_normalize(all_numeric_predictors()) |>
  step_smote(Churn)


# ── 4. Vérification des recettes (optionnel) ─────────────────────────────────
#
# Mettre affichage_des_verifs <- TRUE pour inspecter les recettes préparées.
# NE PAS activer lors du sourcing normal 

affichage_des_verifs <- FALSE

if (affichage_des_verifs) {
  # 4.1 recipe_tree : vérifier que les facteurs sont préservés et que
  #     SMOTENC rééquilibre bien Churn
  recipe_tree |>
    prep() |>
    juice() |>
    count(Churn)

  # 4.2 recipe_xgb : vérifier que toutes les colonnes sont numériques
  #     et que Churn est rééquilibré
  recipe_xgb |>
    prep() |>
    juice() |>
    count(Churn)

  # 4.3 recipe_distance : vérifier que moyenne ≈ 0 et écart-type ≈ 1
  #     sur les variables numériques normalisées
  recipe_distance |>
    prep() |>
    juice() |>
    summarise(across(where(is.numeric), list(moy = mean, sd = sd))) |>
    glimpse()
}


# ── Nettoyage de l'environnement ─────────────────────────────────────────────

rm(list = setdiff(ls(), c(
  "data",
  "churn_split",
  "train_data",
  "test_data",
  "churn_folds",
  "recipe_tree",
  "recipe_xgb",
  "recipe_distance"
)))
