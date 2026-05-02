# ══════════════════════════════════════════════════════════════════════════════
# 09_evaluation_finale.R
# ══════════════════════════════════════════════════════════════════════════════
#
# Ce script constitue l'étape finale obligatoire de tout projet de
# modélisation supervisée :
#   1. Sélectionner le meilleur modèle issu du tuning (ROC AUC)
#   2. Finaliser son workflow avec les meilleurs hyperparamètres
#   3. Entraîner sur tout le train set et évaluer sur le test set (last_fit)
#   4. Comparer les métriques CV vs test (détection du surapprentissage)
#   5. Tracer la courbe ROC et la matrice de confusion finales
#   6. Visualiser l'importance des variables
#
# Sans cette étape, aucun chiffre de performance n'est défendable :
# les métriques de validation croisée estiment la capacité de généralisation
# mais ne constituent pas une évaluation sur des données vraiment inédites.
#
# Prérequis : tuning_results (issu de 07_tuning_benchmark.R)
#             churn_split, train_data, test_data (issus de 02)
#
# Objets exportés :
#   Tableaux   : tableau_final_metrics, tableau_cv_vs_test
#   Graphiques : plot_final_roc, plot_final_conf_mat, plot_vip
#   Modèle     : final_fit (last_fit — contient le modèle entraîné sur train)

library(tidymodels)
library(knitr)
library(kableExtra)
library(vip)


# ── 0. Chargement des prérequis si nécessaire ────────────────────────────────

if (!exists("tuning_results")) {
  tuning_results <- readRDS("data/tuning_results_churn.rds")
}

if (!exists("churn_split")) {
  source("script/00_presentation_des_donnees.R")
  source("script/02_echantillon_et_recipe.R")
}

options(yardstick.event_first = FALSE)
churn_metrics <- metric_set(roc_auc, f_meas, precision, recall, accuracy)

# Palette et noms de modèles (cohérence visuelle avec les scripts précédents)
palette_modeles <- c(
  "xgb_xgb"      = "#E24B4A",
  "tree_rf"       = "#378ADD",
  "tree_bag"      = "#1D9E75",
  "tree_dt"       = "#BA7517",
  "dist_logit"    = "#7F77DD",
  "dist_knn"      = "#D85A30",
  "dist_svm_lin"  = "#888780",
  "dist_svm_rad"  = "#D4537E",
  "discrim_lda"   = "#6B8E23",
  "discrim_qda"   = "#20B2AA"
)

noms_modeles <- c(
  "xgb_xgb"      = "XGBoost",
  "tree_rf"       = "Random Forest",
  "tree_bag"      = "Bagging",
  "tree_dt"       = "Decision Tree",
  "dist_logit"    = "Logistic Reg.",
  "dist_knn"      = "KNN",
  "dist_svm_lin"  = "SVM Linéaire",
  "dist_svm_rad"  = "SVM RBF",
  "discrim_lda"   = "LDA",
  "discrim_qda"   = "QDA"
)


# ══════════════════════════════════════════════════════════════════════════════
# 1. SÉLECTION ET FINALISATION DU MEILLEUR MODÈLE
# ══════════════════════════════════════════════════════════════════════════════

best_wflow_id <- tuning_results |>
  rank_results(rank_metric = "roc_auc", select_best = TRUE) |>
  filter(.metric == "roc_auc") |>
  slice_max(mean, n = 1) |>
  pull(wflow_id)

message("Meilleur modèle sélectionné : ", best_wflow_id,
        " (", noms_modeles[best_wflow_id], ")")

# Extraire le workflow de base et le résultat du tuning
best_workflow <- tuning_results |> extract_workflow(id = best_wflow_id)
best_result   <- tuning_results |>
  extract_workflow_set_result(id = best_wflow_id)

# Finaliser avec les meilleurs hyperparamètres (si modèle tuné)
# Pour les modèles à hyperparamètres fixes (bag, logit, lda, qda),
# le workflow est utilisé tel quel.
if (inherits(best_result, "tune_results")) {
  best_params    <- select_best(best_result, metric = "roc_auc")
  final_workflow <- best_workflow |> finalize_workflow(best_params)
} else {
  final_workflow <- best_workflow
  best_params    <- tibble(note = "Hyperparamètres fixes (pas de tuning)")
}


# ══════════════════════════════════════════════════════════════════════════════
# 2. ENTRAÎNEMENT FINAL ET ÉVALUATION SUR LE TEST SET
# ══════════════════════════════════════════════════════════════════════════════
#
# last_fit() :
#   - Entraîne le workflow finalisé sur l'intégralité du train set
#   - Évalue sur le test set (données jamais vues pendant CV ni tuning)
#   - Stocke les prédictions et le modèle ajusté

set.seed(2026)

final_fit <- final_workflow |>
  last_fit(churn_split, metrics = churn_metrics)

final_metrics     <- final_fit |> collect_metrics()
final_predictions <- final_fit |> collect_predictions()


# ══════════════════════════════════════════════════════════════════════════════
# 3. TABLEAU DES MÉTRIQUES FINALES (TEST SET)
# ══════════════════════════════════════════════════════════════════════════════

tableau_final_metrics <- final_metrics |>
  select(.metric, .estimate) |>
  mutate(
    Métrique = c("ROC AUC", "F1-Score", "Precision", "Recall", "Accuracy"),
    Valeur   = sprintf("%.2f%%", .estimate * 100)
  ) |>
  select(Métrique, Valeur) |>
  kable(
    booktabs = TRUE,
    caption  = paste0(
      "Métriques finales sur le test set — ",
      noms_modeles[best_wflow_id]
    ),
    align    = c("l", "c")
  ) |>
  kable_styling(
    latex_options = c("striped", "hold_position"),
    font_size     = 10
  )


# ══════════════════════════════════════════════════════════════════════════════
# 4. COMPARAISON CV VS TEST SET (DÉTECTION DU SURAPPRENTISSAGE)
# ══════════════════════════════════════════════════════════════════════════════
#
# Un écart important CV → test indique du surapprentissage.
# Un écart nul ou positif (test > CV) est acceptable.

cv_metrics <- tuning_results |>
  rank_results(rank_metric = "roc_auc", select_best = TRUE) |>
  filter(
    wflow_id == best_wflow_id,
    .metric %in% c("roc_auc", "f_meas", "precision", "recall", "accuracy")
  ) |>
  select(.metric, cv_mean = mean, cv_se = std_err)

tableau_cv_vs_test <- final_metrics |>
  select(.metric, test = .estimate) |>
  left_join(cv_metrics, by = ".metric") |>
  mutate(
    Métrique = case_match(
      .metric,
      "roc_auc"  ~ "ROC AUC",
      "f_meas"   ~ "F1-Score",
      "precision" ~ "Precision",
      "recall"   ~ "Recall",
      "accuracy" ~ "Accuracy"
    ),
    `CV (moyenne)` = sprintf("%.2f%%", cv_mean * 100),
    `Test set`     = sprintf("%.2f%%", test * 100),
    `Écart`        = sprintf("%+.2f pp", (test - cv_mean) * 100)
  ) |>
  select(Métrique, `CV (moyenne)`, `Test set`, `Écart`) |>
  kable(
    booktabs = TRUE,
    caption  = paste0(
      "Comparaison CV vs test set — ",
      noms_modeles[best_wflow_id],
      " (écart en points de pourcentage)"
    ),
    align    = c("l", "c", "c", "c")
  ) |>
  kable_styling(
    latex_options = c("striped", "hold_position"),
    font_size      = 10
  )


# ══════════════════════════════════════════════════════════════════════════════
# 5. COURBE ROC FINALE (TEST SET)
# ══════════════════════════════════════════════════════════════════════════════

auc_val <- final_metrics |>
  filter(.metric == "roc_auc") |>
  pull(.estimate)

plot_final_roc <- final_predictions |>
  roc_curve(truth = Churn, .pred_Yes, event_level = "second") |>
  ggplot(aes(x = 1 - specificity, y = sensitivity)) +
  geom_line(linewidth = 1.2, colour = palette_modeles[best_wflow_id]) +
  geom_abline(linetype = "dashed", colour = "grey60", linewidth = 0.5) +
  # annotate() évalue ses arguments immédiatement (contrairement à aes()),
  # ce qui évite l'erreur "objet introuvable" après rm().
  annotate(
    geom       = "label",
    x          = 0.75,
    y          = 0.15,
    label      = paste0("AUC = ", sprintf("%.3f", auc_val)),
    size       = 4,
    fontface   = "bold",
    colour     = palette_modeles[best_wflow_id],
    fill       = "white",
    label.size = 0.4
  ) +
  scale_x_continuous(labels = scales::label_percent()) +
  scale_y_continuous(labels = scales::label_percent()) +
  labs(
    title    = paste0(
      "Courbe ROC finale — ", noms_modeles[best_wflow_id]
    ),
    subtitle = "Évaluation sur le test set (données inédites)",
    x        = "1 − Spécificité (Taux de faux positifs)",
    y        = "Sensibilité (Recall)"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title    = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(colour = "grey40")
  )


# ══════════════════════════════════════════════════════════════════════════════
# 6. MATRICE DE CONFUSION FINALE (TEST SET)
# ══════════════════════════════════════════════════════════════════════════════
#
# Même convention que les scripts précédents :
# tidy.conf_mat() → "cell_R_C", R = indice ligne (pred), C = indice col (truth)

plot_final_conf_mat <- final_predictions |>
  conf_mat(truth = Churn, estimate = .pred_class) |>
  tidy() |>
  separate(name, into = c("prefix", "pred_idx", "truth_idx"), sep = "_") |>
  mutate(
    pred_class  = c("No", "Yes")[as.integer(pred_idx)],
    truth_class = c("No", "Yes")[as.integer(truth_idx)],
    cell_type   = case_when(
      pred_class == "No"  & truth_class == "No"  ~ "VN",
      pred_class == "Yes" & truth_class == "No"  ~ "FP",
      pred_class == "No"  & truth_class == "Yes" ~ "FN",
      pred_class == "Yes" & truth_class == "Yes" ~ "VP"
    )
  ) |>
  ggplot(aes(x = truth_class, y = pred_class, fill = value)) +
  geom_tile(colour = "white", linewidth = 1) +
  geom_text(
    aes(label = paste0(cell_type, "\n", value)),
    size = 5, fontface = "bold", colour = "white"
  ) +
  scale_fill_gradient(
    low  = "#B5D4F4",
    high = palette_modeles[best_wflow_id],
    name = "Effectif"
  ) +
  labs(
    title    = paste0(
      "Matrice de confusion finale — ", noms_modeles[best_wflow_id]
    ),
    subtitle = "Test set | VN/VP = correct, FN/FP = erreur",
    x        = "Churn réel",
    y        = "Churn prédit"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title    = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(colour = "grey40"),
    panel.grid    = element_blank()
  )


# ══════════════════════════════════════════════════════════════════════════════
# 7. IMPORTANCE DES VARIABLES
# ══════════════════════════════════════════════════════════════════════════════
#
# Extraire le modèle ajusté depuis le last_fit pour accéder aux importances.
# Fonctionne pour Random Forest (permutation) et XGBoost (gain).
# Pour LDA/QDA/SVM/KNN, vip() ne produit pas d'importance — on gère ce cas.

final_fitted_wf    <- extract_workflow(final_fit)
final_fitted_model <- extract_fit_parsnip(final_fitted_wf)

modeles_avec_vip <- c("xgb_xgb", "tree_rf", "tree_bag", "tree_dt")

if (best_wflow_id %in% modeles_avec_vip) {
  plot_vip <- final_fitted_model |>
    vip(
      num_features = 15,
      aesthetics   = list(
        fill   = palette_modeles[best_wflow_id],
        colour = "white",
        alpha  = 0.85
      )
    ) +
    labs(
      title    = paste0(
        "Importance des variables — ", noms_modeles[best_wflow_id]
      ),
      subtitle = "15 variables les plus importantes",
      x        = "Importance",
      y        = NULL
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title    = element_text(face = "bold", size = 14),
      plot.subtitle = element_text(colour = "grey40")
    )
} else {
  message(
    "vip() non disponible pour ", noms_modeles[best_wflow_id],
    " — importance des variables non applicable."
  )
  plot_vip <- NULL
}


# ══════════════════════════════════════════════════════════════════════════════
# 8. RÉSUMÉ CONSOLE
# ══════════════════════════════════════════════════════════════════════════════

message("\n", strrep("═", 60))
message("RÉSULTATS FINAUX — ", toupper(noms_modeles[best_wflow_id]))
message(strrep("═", 60))
message(sprintf("  ROC AUC  : %.3f", auc_val))
message(sprintf(
  "  F1-Score : %.3f",
  final_metrics |> filter(.metric == "f_meas") |> pull(.estimate)
))
message(sprintf(
  "  Recall   : %.3f",
  final_metrics |> filter(.metric == "recall") |> pull(.estimate)
))
message(sprintf(
  "  Accuracy : %.3f",
  final_metrics |> filter(.metric == "accuracy") |> pull(.estimate)
))
message(strrep("═", 60), "\n")


# ── Nettoyage de l'environnement ─────────────────────────────────────────────

rm(list = setdiff(ls(), c(
  "data",
  "churn_split", "train_data", "test_data", "churn_folds",
  "recipe_tree", "recipe_xgb", "recipe_distance", "recipe_lda_qda",
  "logit_spec", "tree_spec", "bagging_spec", "rf_spec", "xgb_spec",
  "knn_spec", "svm_lin_spec", "svm_rad_spec", "lda_spec", "qda_spec",
  "rf_tune_spec", "xgb_tune_spec",
  "knn_tune_spec", "svm_lin_tune_spec", "svm_rad_tune_spec", "tree_tune_spec",
  "all_workflows", "tuning_workflows", "fixed_workflows",
  "churn_metrics",
  "tuning_results",
  "best_params", "best_params_detail",
  "best_wflow_id", "final_workflow", "final_fit",
  "final_metrics", "final_predictions",
  "palette_modeles", "noms_modeles",
  "tableau_final_metrics", "tableau_cv_vs_test",
  "plot_final_roc", "plot_final_conf_mat", "plot_vip",
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
