# Ce fichier construit le workflow set en associant chaque recette à sa famille
# de modèles compatible (définis dans 02 et 03).
#
# Principe : cross = TRUE génère toutes les combinaisons recette x modèle,
# puis filter() ne conserve que les paires méthodologiquement valides :
#
#   recipe_tree     <- tree_spec, bagging_spec, rf_spec
#   recipe_xgb      <- xgb_spec
#   recipe_distance <- logit_spec, knn_spec, svm_lin_spec, svm_rad_spec
#   recipe_lda_qda  <- lda_spec, qda_spec
#
# Prérequis : objets issus de 02_echantillon_et_recipe.R et 03_model_spec.R

library(tidymodels)


# ── Construction du workflow set ─────────────────────────────────────────────

all_workflows <- workflow_set(
  preproc = list(
    tree    = recipe_tree, # arbres
    xgb     = recipe_xgb, # XGBoost
    dist    = recipe_distance, # distance + linéaire
    discrim = recipe_lda_qda # analyse discriminante (LDA/QDA)
  ),
  models = list(
    logit   = logit_spec, # baseline logistique (recipe_distance)
    dt      = tree_spec, # arbre de décision   (recipe_tree)
    bag     = bagging_spec, # bagging             (recipe_tree)
    rf      = rf_spec, # random forest       (recipe_tree)
    xgb     = xgb_spec, # XGBoost             (recipe_xgb)
    knn     = knn_spec, # KNN                 (recipe_distance)
    svm_lin = svm_lin_spec, # SVM linéaire        (recipe_distance)
    svm_rad = svm_rad_spec, # SVM RBF             (recipe_distance)
    lda     = lda_spec, # LDA                 (recipe_lda_qda)
    qda     = qda_spec # QDA                 (recipe_lda_qda)
  ),
  cross = TRUE
) |>
  filter(wflow_id %in% c(
    # Arbres et ensemble
    "tree_dt", "tree_bag", "tree_rf",
    # Boosting
    "xgb_xgb",
    # Distance et linéaire (normalisation + dummies)
    "dist_logit", "dist_knn", "dist_svm_lin", "dist_svm_rad",
    # Analyse discriminante (normalisation + ACP)
    "discrim_lda", "discrim_qda"
  ))


# ── Vérification (optionnel) ─────────────────────────────────────────────────

affichage_workflow <- FALSE

if (affichage_workflow) {
  all_workflows |> pull(wflow_id)
}


# ── Nettoyage de l'environnement ─────────────────────────────────────────────

rm(list = setdiff(ls(), c(
  "data",
  "churn_split", "train_data", "test_data", "churn_folds",
  "recipe_tree", "recipe_xgb", "recipe_distance", "recipe_lda_qda",
  "logit_spec",
  "tree_spec", "bagging_spec", "rf_spec", "xgb_spec",
  "knn_spec", "svm_lin_spec", "svm_rad_spec",
  "lda_spec", "qda_spec",
  "all_workflows",
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
