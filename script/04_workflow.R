library(tidymodels)


# ── Construction du workflow set ─────────────────────────────────────────────
# cross = TRUE génère toutes les combinaisons, filter() ne conserve que
# les paires méthodologiquement valides :
#   recipe_tree     <- tree_spec, bagging_spec, rf_spec
#   recipe_xgb      <- xgb_spec
#   recipe_distance <- logit_spec, knn_spec, svm_lin_spec, svm_rad_spec

all_workflows <- workflow_set(
  preproc = list(
    tree = recipe_tree,
    xgb  = recipe_xgb,
    dist = recipe_distance
  ),
  models = list(
    logit   = logit_spec,
    dt      = tree_spec,
    bag     = bagging_spec,
    rf      = rf_spec,
    xgb     = xgb_spec,
    knn     = knn_spec,
    svm_lin = svm_lin_spec,
    svm_rad = svm_rad_spec
  ),
  cross = TRUE
) |>
  filter(wflow_id %in% c(
    "tree_dt", "tree_bag", "tree_rf",
    "xgb_xgb",
    "dist_logit", "dist_knn", "dist_svm_lin", "dist_svm_rad"
  ))


# ── Nettoyage de l'environnement ─────────────────────────────────────────────

rm(list = setdiff(ls(), c(
  "data",
  "churn_split", "train_data", "test_data", "churn_folds",
  "recipe_tree", "recipe_xgb", "recipe_distance",
  "logit_spec", "tree_spec", "bagging_spec", "rf_spec", "xgb_spec",
  "knn_spec", "svm_lin_spec", "svm_rad_spec",
  "all_workflows",
  "tableau_presentation_donnees",
  "tableau_summary_num", "tableau_summary_cat",
  "plot_desequilibre", "plot_dist_num", "plot_boxplot_churn",
  "plot_correlation", "plot_cat_churn",
  "couleurs_churn"
)))