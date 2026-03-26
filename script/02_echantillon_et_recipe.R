# Ce script prépare les données pour nos différents modèles
# sépare entre train et test et validation croisée en prenant en compte
# le déséquilibre de la variable cible

# préparation des différentes recipe pour les différents modèles en suivant les recommendations
# de la documentation : https://www.tmwr.org/pre-proc-table.html



library(tidymodels)
library(themis)

set.seed(2026)

churn_split <- initial_split(data, prop = 0.80, strata = Churn)


train_data <- training(churn_split)
test_data <- testing(churn_split)
churn_folds <- vfold_cv(train_data, v = 10, strata = Churn)


# recipe pour les arbres de décision -----------------------

recipe_tree <- recipe(Churn ~ ., data = train_data) %>%
  step_impute_median(all_numeric_predictors()) %>%
  step_impute_mode(all_nominal_predictors()) %>%
  step_dummy(all_nominal_predictors()) %>% # inutile pour arbres mais
  # nécessaire pour smote (création de nouveaux client)

  step_smote(Churn)


# recipe pour les modèles de boosting et ensemble ---------

recipe_xgb <- recipe(Churn ~ ., data = train_data) %>%
  step_impute_median(all_numeric_predictors()) %>%
  step_impute_mode(all_nominal_predictors()) %>%
  step_dummy(all_nominal_predictors(), one_hot = TRUE) %>% # requis pour xgboost
  step_zv(all_predictors()) %>%
  step_smote(Churn)


# recipe pour modèles de distance (knn, svm) ---------------------

recipe_distance <- recipe(Churn ~ ., data = train_data) %>%
  step_impute_median(all_numeric_predictors()) %>%
  step_impute_mode(all_nominal_predictors()) %>%
  step_dummy(all_nominal_predictors()) %>%
  step_zv(all_predictors()) %>%
  step_normalize(all_numeric_predictors()) %>%
  step_smote(Churn)


# recipe pour les modèles discriminants ------------------------
# INADAPTE à supprimer après justification dans le rapport
#
# recipe_discrim <- recipe(Churn ~ ., data = train_data) %>%
#   step_impute_median(all_numeric_predictors()) %>%
#   step_impute_mode(all_nominal_predictors()) %>%
#   step_dummy(all_nominal_predictors()) %>%
#   step_zv(all_predictors()) %>%
#   step_lincomb(all_predictors()) %>%
#   step_corr(all_numeric_predictors(), threshold = 0.9) %>%
#   step_smote(Churn) |>
#   step_lincomb(all_predictors())


# RECIPE GLOBAL MAIS MOINS ADAPTE POUR CHAQUE MODELE

# churn_recipe <- recipe(Churn~., data = train_data) %>%
#   step_impute_median(all_numeric_predictors()) %>% #remplace NA par médiane mais inutile ici
#   step_impute_mode(all_nominal_predictors()) %>% #comme au dessus mais pour les catégorielles
#   step_nzv(all_predictors()) %>% # retire les variables qui n'apporte pas d'information utile
#
#   step_dummy(all_nominal_predictors(), one_hot = TRUE) %>% # dummy pour xgboost / svm / knn
#   step_zv(all_predictors()) %>% # retire tout ce qui a exactement la même valeur
#   step_normalize(all_numeric_predictors()) %>%
#   step_smote(Churn) # gestion du déséquilibre


# VERIFICATION DES RECIPES AVANT CALCUL ----------------------------

affichage_des_verifs <- FALSE


if (affichage_des_verifs) {
  # recipe Arbres
  recipe_tree %>%
    prep() %>%
    juice() %>%
    glimpse() %>%
    count(Churn)


  # recipe XGBoost
  recipe_xgb %>%
    prep() %>%
    juice() %>%
    glimpse()

  # recipe Distance -> moyenne proche de 0 et ecart type proche de 1
  recipe_distance %>%
    prep() %>%
    juice() %>%
    summarise(across(where(is.numeric), list(mean = mean, sd = sd))) %>%
    glimpse()

  # recipe Discriminante -> supprime les variables corrélés
  # recipe_discrim %>%
  #   prep() %>%
  #   juice() %>%
  #   ncol()
}
