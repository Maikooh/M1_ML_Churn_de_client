library(tidymodels)
library(kknn)     # nearest_neighbor()
library(ranger)   # rand_forest()
library(xgboost)  # boost_tree()
library(kernlab)  # svm_rbf(), svm_linear()
library(discrim)  # lda(), qda()


# ── 1. Baseline ──────────────────────────────────────────────────────────────
# Régression logistique sans régularisation pour le benchmark initial

logit_spec <- logistic_reg(penalty = 0) |>
  set_engine("glm") |>
  set_mode("classification")


# ── 2. Arbres et méthodes d'ensemble ─────────────────────────────────────────

# Arbre de décision
tree_spec <- decision_tree() |>
  set_engine("rpart") |>
  set_mode("classification")

# Bagging : mtry = .preds() (tous les prédicteurs, résolu dynamiquement au fit)
bagging_spec <- rand_forest(trees = 500, mtry = .preds()) |>
  set_engine("ranger") |>
  set_mode("classification")

# Random Forest : mtry par défaut = sqrt(p), importance par permutation
rf_spec <- rand_forest(trees = 500) |>
  set_engine("ranger", importance = "permutation") |>
  set_mode("classification")

# XGBoost : learn_rate abaissé à 0.05 pour limiter le surapprentissage
xgb_spec <- boost_tree(trees = 500, learn_rate = 0.05, stop_iter = 20) |>
  set_engine("xgboost") |>
  set_mode("classification")


# ── 3. Modèles à base de distance ────────────────────────────────────────────
# Nécessitent recipe_distance (normalisation obligatoire)

# KNN : neighbors = 10 comme valeur initiale raisonnée pour n ≈ 2500
knn_spec <- nearest_neighbor(neighbors = 10) |>
  set_engine("kknn") |>
  set_mode("classification")

# SVM linéaire
svm_lin_spec <- svm_linear() |>
  set_engine("kernlab") |>
  set_mode("classification")

# SVM RBF
svm_rad_spec <- svm_rbf() |>
  set_engine("kernlab") |>
  set_mode("classification")


# ── 4. Méthodes discriminantes ───────────────────────────────────────────────
# Nécessitent recipe_lda_qda (normalisation + ACP)

lda_spec <- discrim_linear() |>
  set_engine("MASS") |>
  set_mode("classification")

qda_spec <- discrim_quad() |>
  set_engine("MASS") |>
  set_mode("classification")


# ── Nettoyage de l'environnement ─────────────────────────────────────────────

rm(list = setdiff(ls(), c(
  "data",
  "churn_split", "train_data", "test_data", "churn_folds",
  "recipe_tree", "recipe_xgb", "recipe_distance", "recipe_lda_qda",
  "logit_spec", "tree_spec", "bagging_spec", "rf_spec", "xgb_spec",
  "knn_spec", "svm_lin_spec", "svm_rad_spec",
  "lda_spec", "qda_spec",
  "tableau_presentation_donnees",
  "tableau_summary_num", "tableau_summary_cat",
  "plot_desequilibre", "plot_dist_num", "plot_boxplot_churn",
  "plot_correlation", "plot_cat_churn",
  "couleurs_churn"
)))