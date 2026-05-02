## Utilities partagées pour les scripts du projet

# Chargement des packages couramment utilisés
library(tidyverse)
library(tidymodels)
library(knitr)
library(kableExtra)
library(themis)
library(finetune)
library(future)
library(doFuture)
library(ranger)
library(xgboost)
library(kknn)
library(kernlab)
library(discrim)
library(vip)
library(forcats)
# Options globales
options(yardstick.event_first = FALSE)

# Palettes et noms de modèles (utilisés dans plusieurs scripts)
couleurs_churn <- c("No" = "#4999da", "Yes" = "#f13a3a")

palette_modeles <- c(
  "xgb_xgb"      = "#E24B4A",
  "tree_rf"      = "#378ADD",
  "tree_bag"     = "#1D9E75",
  "tree_dt"      = "#BA7517",
  "dist_logit"   = "#7F77DD",
  "dist_knn"     = "#D85A30",
  "dist_svm_lin" = "#888780",
  "dist_svm_rad" = "#D4537E",
  "discrim_lda"  = "#6B8E23",
  "discrim_qda"  = "#20B2AA"
)

noms_modeles <- c(
  "xgb_xgb"      = "XGBoost",
  "tree_rf"      = "Random Forest",
  "tree_bag"     = "Bagging",
  "tree_dt"      = "Decision Tree",
  "dist_logit"   = "Logistic Reg.",
  "dist_knn"     = "KNN",
  "dist_svm_lin" = "SVM Linéaire",
  "dist_svm_rad" = "SVM RBF",
  "discrim_lda"  = "LDA",
  "discrim_qda"  = "QDA"
)

# Jeu de métriques réutilisé
churn_metrics <- metric_set(roc_auc, f_meas, precision, recall, accuracy)
