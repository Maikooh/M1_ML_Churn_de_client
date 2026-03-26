# Ce fichier contient les différents modèles à utiliser dans le benchmark initial
# les modèles sont organisés par catégorie :
# les modèles d'arbres et d'ensemble
# les modèles géométriques basés sur la distance
# les modèles géométriques basés sur la discrimination

library(tidymodels)
library(discrim)
library(kknn)
library(ranger)
library(xgboost)
library(kernlab)


# arbres et ensemble --------------------

# random forest
rf_spec <- rand_forest(trees = 1000) %>%
  set_engine("ranger", importance = "permutation") %>%
  set_mode("classification")

# boosting
xgb_spec <- boost_tree(trees = 1000) %>%
  set_engine("xgboost") %>%
  set_mode("classification")

# bagging
bagging_spec <- rand_forest(trees = 1000, mtry = .preds()) %>%
  set_engine("ranger") %>%
  set_mode("classification")

# arbre de décision
tree_spec <- decision_tree() %>%
  set_engine("rpart") %>%
  set_mode("classification")


# modèle géométrique (distance) ---------------

# knn
knn_spec <- nearest_neighbor(neighbors = 10) %>%
  set_engine("kknn") %>%
  set_mode("classification")

# svm rad
svm_rad_spec <- svm_rbf() %>%
  set_engine("kernlab") %>%
  set_mode("classification")

# svm lin
svm_lin_spec <- svm_linear() %>%
  set_engine("kernlab") %>%
  set_mode("classification")


# modèle géométrique (discriminant) -----------------------
# SUPRESSION CAR INADAPTE AU PROBLEME MAIS CONSERVER TEMPORAIREMENT POUR JUSTIFIER DANS LE RAPPORT

# # lda
# lda_spec <- discrim_linear() %>%
#   set_engine("MASS") %>%
#   set_mode("classification")
#
# # qda
# qda_spec <- discrim_quad() %>%
#   set_engine("MASS") %>%
#   set_mode("classification")
