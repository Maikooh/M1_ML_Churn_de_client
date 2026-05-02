library(tidymodels)
library(themis) # step_smote(), step_smotenc()

set.seed(2026)


# ── 1. Split train / test ────────────────────────────────────────────────────
# Stratification sur Churn pour préserver les proportions (~16 %) dans les deux ensembles

churn_split <- initial_split(data, prop = 0.80, strata = Churn)
train_data  <- training(churn_split)
test_data   <- testing(churn_split)


# ── 2. Validation croisée ────────────────────────────────────────────────────
# 10 folds stratifiés sur le train set uniquement

churn_folds <- vfold_cv(train_data, v = 10, strata = Churn)


# ── 3. Recettes de préprocessing ─────────────────────────────────────────────
# Une recette par famille : chaque famille a des exigences différentes
# SMOTE toujours en dernière étape (synthèse sur le fold d'analyse uniquement)

# 3.1 Arbres (Random Forest, Bagging, Decision Tree)
# step_smotenc() gère les données mixtes sans dummification préalable
recipe_tree <- recipe(Churn ~ ., data = train_data) |>
  step_impute_median(all_numeric_predictors()) |>
  step_impute_mode(all_nominal_predictors()) |>
  step_smotenc(Churn)

# 3.2 XGBoost
# one_hot = TRUE : XGBoost attend des matrices purement numériques
recipe_xgb <- recipe(Churn ~ ., data = train_data) |>
  step_impute_median(all_numeric_predictors()) |>
  step_impute_mode(all_nominal_predictors()) |>
  step_dummy(all_nominal_predictors(), one_hot = TRUE) |>
  step_zv(all_predictors()) |>
  step_smote(Churn)

# 3.3 Distance (KNN, SVM linéaire, SVM RBF)
# step_normalize() indispensable : KNN et SVM sont sensibles aux échelles
# Normalisation avant SMOTE : interpolation dans l'espace normalisé
recipe_distance <- recipe(Churn ~ ., data = train_data) |>
  step_impute_median(all_numeric_predictors()) |>
  step_impute_mode(all_nominal_predictors()) |>
  step_dummy(all_nominal_predictors()) |>
  step_zv(all_predictors()) |>
  step_normalize(all_numeric_predictors()) |>
  step_smote(Churn)


# ── 4. Recette LDA / QDA ─────────────────────────────────────────────────────
# ACP (seuil 95 %) pour décorréler les prédicteurs et stabiliser
# l'estimation des matrices de covariance (hypothèse de normalité multivariée)
recipe_lda_qda <- recipe(Churn ~ ., data = train_data) |>
  step_impute_median(all_numeric_predictors()) |>
  step_impute_mode(all_nominal_predictors()) |>
  step_dummy(all_nominal_predictors()) |>
  step_zv(all_predictors()) |>
  step_normalize(all_numeric_predictors()) |>
  step_pca(all_numeric_predictors(), threshold = 0.95) |>
  step_smote(Churn)


# ── Nettoyage de l'environnement ─────────────────────────────────────────────

rm(list = setdiff(ls(), c(
  "data",
  "churn_split", "train_data", "test_data", "churn_folds",
  "recipe_tree", "recipe_xgb", "recipe_distance", "recipe_lda_qda",
  "tableau_presentation_donnees",
  "tableau_summary_num", "tableau_summary_cat",
  "plot_desequilibre", "plot_dist_num", "plot_boxplot_churn",
  "plot_correlation", "plot_cat_churn",
  "couleurs_churn"
)))