# Ce fichier définit les spécifications des modèles pour le benchmark initial.
# Les modèles sont organisés en trois familles :
#   1. Baseline          : régression logistique (pour référence)
#   2. Arbres et ensemble : Decision Tree, Bagging, Random Forest, XGBoost
#   3. Distance          : KNN, SVM linéaire, SVM RBF
#
# Aucun hyperparamètre n'est marqué tune() ici : ce fichier sert au benchmark
# initial avec des valeurs par défaut raisonnées. Les spécifications de tuning
# seront définies plus tard.
#
# Note sur LDA / QDA : exclus car leurs hypothèses sont incompatibles avec ce
# jeu de données. LDA suppose la normalité multivariée et l'égalité des matrices
# de covariance entre classes ; QDA suppose la normalité multivariée. Or
# plusieurs variables sont binaires (Complains, Status, Tariff Plan) ou
# ordinales (Age Group, Charge Amount), ce qui viole structurellement ces
# hypothèses. Leur inclusion produirait des résultats non interprétables.
#
# Prérequis : aucun objet nécessaire, fichier autonome.

library(tidymodels)
library(kknn) # nearest_neighbor() engine
library(ranger) # rand_forest() engine
library(xgboost) # boost_tree() engine
library(kernlab) # svm_rbf() et svm_linear() engine
# Note : library(discrim) retiré — LDA et QDA exclus (cf. justification ci-dessus)


# ── 1. Baseline ──────────────────────────────────────────────────────────────
#
# La régression logistique est la référence minimale de tout benchmark de
# classification binaire. Si un modèle plus complexe ne la surpasse pas
# clairement, sa complexité supplémentaire n'est pas justifiée.
# penalty = 0 : pas de régularisation pour le benchmark initial.

logit_spec <- logistic_reg(penalty = 0) |>
  set_engine("glm") |>
  set_mode("classification")


# ── 2. Arbres et méthodes d'ensemble ─────────────────────────────────────────

# Arbre de décision (benchmark simple, interprétable)
tree_spec <- decision_tree() |>
  set_engine("rpart") |>
  set_mode("classification")

# Bagging : Random Forest avec mtry = nombre total de prédicteurs (.preds()).
# .preds() est résolu dynamiquement au moment du fit selon la recette utilisée.
bagging_spec <- rand_forest(trees = 500, mtry = .preds()) |>
  set_engine("ranger") |>
  set_mode("classification")

# Random Forest : mtry par défaut = sqrt(p), importance par permutation
# pour l'interprétabilité en phase d'évaluation.
rf_spec <- rand_forest(trees = 500) |>
  set_engine("ranger", importance = "permutation") |>
  set_mode("classification")

# XGBoost : learn_rate abaissé à 0.05 (défaut = 0.3) pour limiter le risque
# de surapprentissage avec trees = 500 en l'absence de tuning.
# stop_iter = 20 active l'early stopping sur le fold d'évaluation interne.
xgb_spec <- boost_tree(trees = 500, learn_rate = 0.05, stop_iter = 20) |>
  set_engine("xgboost") |>
  set_mode("classification")


# ── 3. Modèles à base de distance ────────────────────────────────────────────
#
# Ces trois modèles utilisent recipe_distance (normalisation obligatoire).

# KNN : neighbors = 10 comme valeur initiale raisonnée pour n = ~2500.
# La règle empirique sqrt(n) ≈ 50 sera explorée en phase de tuning.
knn_spec <- nearest_neighbor(neighbors = 10) |>
  set_engine("kknn") |>
  set_mode("classification")

# SVM linéaire : adapté si les classes sont linéairement séparables.
svm_lin_spec <- svm_linear() |>
  set_engine("kernlab") |>
  set_mode("classification")

# SVM RBF : plus flexible, peut capturer des frontières non linéaires.
svm_rad_spec <- svm_rbf() |>
  set_engine("kernlab") |>
  set_mode("classification")


# ── Nettoyage de l'environnement ─────────────────────────────────────────────

rm(list = setdiff(ls(), c(
  "data",
  "churn_split",
  "train_data",
  "test_data",
  "churn_folds",
  "recipe_tree",
  "recipe_xgb",
  "recipe_distance",
  "logit_spec",
  "tree_spec",
  "bagging_spec",
  "rf_spec",
  "xgb_spec",
  "knn_spec",
  "svm_lin_spec",
  "svm_rad_spec",
  "tableau_presentation_donnees",
  "tableau_summary_num",
  "tableau_summary_cat",
  "plot_desequilibre",
  "plot_dist_num",
  "plot_boxplot_churn",
  "plot_correlation",
  "plot_cat_churn",
  "couleurs_churn"
)))
