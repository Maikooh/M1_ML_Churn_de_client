# Ce fichier contient le workflow set liant recipe et model spec
# fichier 02 et 03

library(workflowsets)

all_workflows <- workflow_set(
  preproc = list(
    tree    = recipe_tree, # arbre bagging et randomforest
    xgb     = recipe_xgb, # XGBoost
    dist    = recipe_distance # knn et svm
    # discrim = recipe_discrim # lda et qda
  ),
  models = list(
    rf      = rf_spec,
    xgb     = xgb_spec,
    bag     = bagging_spec,
    dt      = tree_spec,
    knn     = knn_spec,
    svm_rad = svm_rad_spec,
    svm_lin = svm_lin_spec
    # lda     = lda_spec, #suppression car inadapté
    # qda     = qda_spec
  ),
  cross = TRUE
) %>%
  filter(wflow_id %in% c(
    "tree_rf", "tree_bag", "tree_dt", # arbres
    "xgb_xgb", # boosting
    "dist_knn", "dist_svm_rad", "dist_svm_lin" # distance
    # "discrim_lda", "discrim_qda" # discriminante -> inadapté au problème suppresion après justification
  ))


# -----------------------------------------------


affichage_workflow <- F

if (affichage_workflow) {
  all_workflows$wflow_id
}
