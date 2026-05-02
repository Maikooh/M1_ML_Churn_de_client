library(tidymodels)
library(xgboost)


# ── 0. Sourcing si nécessaire ────────────────────────────────────────────────

if (!exists("xgb_final_wflow")) {
  source("script/00_presentation_des_donnees.R")
  source("script/01_analyse_exploratoire.R")
  source("script/02_echantillon_et_recipe.R")
  source("script/03_model_spec.R")
  source("script/04_workflow.R")
  source("script/07_xgb_tuning.R")
}

options(yardstick.event_first = FALSE)


# ── 1. Évaluation finale sur le test set ─────────────────────────────────────

xgb_last_fit <- xgb_final_wflow |>
  last_fit(
    split   = churn_split,
    metrics = metric_set(roc_auc, accuracy, f_meas, precision, recall)
  )

test_metrics     <- xgb_last_fit |> collect_metrics()
test_predictions <- xgb_last_fit |> collect_predictions()


# ── 2. Comparaison CV vs test ────────────────────────────────────────────────

cv_roc_auc   <- xgb_zoom_results |>
  collect_metrics() |>
  filter(.metric == "roc_auc") |>
  slice_max(mean, n = 1) |>
  pull(mean)

test_roc_auc <- test_metrics |>
  filter(.metric == "roc_auc") |>
  pull(.estimate)

cv_vs_test <- tibble(
  source  = c("CV (10-fold)", "Test set"),
  roc_auc = c(cv_roc_auc, test_roc_auc)
) |>
  mutate(delta = roc_auc - lag(roc_auc))


# ── 3. Matrice de confusion ──────────────────────────────────────────────────

conf_mat_data <- test_predictions |>
  conf_mat(truth = Churn, estimate = .pred_class)

plot_confusion_matrix <- conf_mat_data |>
  autoplot(type = "heatmap") +
  scale_fill_gradient(low = "#D5E8D4", high = "#82B366") +
  labs(
    title    = "Matrice de confusion — XGBoost (test set)",
    subtitle = paste0("ROC AUC = ", scales::percent(test_roc_auc, accuracy = 0.1))
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"), axis.text = element_text(size = 11))


# ── 4. Courbe ROC ────────────────────────────────────────────────────────────

plot_roc_curve <- test_predictions |>
  roc_curve(truth = Churn, .pred_Yes, event_level = "second") |>
  autoplot() +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", colour = "grey50") +
  labs(
    title    = "Courbe ROC — XGBoost (test set)",
    subtitle = paste0("AUC = ", scales::percent(test_roc_auc, accuracy = 0.1))
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))


# ── 5. Distribution des probabilités prédites ────────────────────────────────

plot_prob_distribution <- test_predictions |>
  ggplot(aes(x = .pred_Yes, fill = Churn)) +
  geom_histogram(bins = 30, alpha = 0.7, position = "identity", colour = "white") +
  geom_vline(xintercept = 0.5, linetype = "dashed", colour = "grey30", linewidth = 0.8) +
  scale_fill_manual(values = c("No" = "#3498DB", "Yes" = "#E74C3C")) +
  scale_x_continuous(labels = scales::percent_format()) +
  labs(
    title    = "Distribution des probabilités prédites",
    subtitle = "Ligne pointillée = seuil de classification (0.5)",
    x        = "P(Churn = Yes)",
    y        = "Nombre d'observations",
    fill     = "Churn"
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"), legend.position = "top")


# ── 6. Analyse du seuil de classification ────────────────────────────────────

threshold_analysis <- test_predictions |>
  probably::threshold_perf(
    truth       = Churn,
    estimate    = .pred_Yes,
    thresholds  = seq(0.1, 0.9, by = 0.05),
    metrics     = metric_set(j_index, sensitivity, specificity),
    event_level = "second"
  )

optimal_threshold <- threshold_analysis |>
  filter(.metric == "j_index") |>
  slice_max(.estimate, n = 1) |>
  pull(.threshold)

plot_threshold_analysis <- threshold_analysis |>
  filter(.metric %in% c("sensitivity", "specificity")) |>
  ggplot(aes(x = .threshold, y = .estimate, colour = .metric)) +
  geom_line(linewidth = 1) +
  geom_vline(xintercept = optimal_threshold, linetype = "dashed", colour = "grey30") +
  annotate("text",
           x = optimal_threshold + 0.05, y = 0.5,
           label = paste("Seuil optimal\n", round(optimal_threshold, 2)),
           hjust = 0, size = 3.5
  ) +
  scale_colour_manual(
    values = c("sensitivity" = "#E74C3C", "specificity" = "#3498DB"),
    labels = c("Sensibilité (Recall)", "Spécificité")
  ) +
  scale_x_continuous(labels = scales::percent_format()) +
  scale_y_continuous(labels = scales::percent_format()) +
  labs(
    title    = "Analyse du seuil de classification",
    subtitle = "Compromis sensibilité / spécificité",
    x        = "Seuil de classification",
    y        = "Performance",
    colour   = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"), legend.position = "top")


# ── 7. Tableau récapitulatif ─────────────────────────────────────────────────

summary_table <- test_metrics |>
  select(.metric, .estimate) |>
  pivot_wider(names_from = .metric, values_from = .estimate) |>
  mutate(
    cv_roc_auc        = cv_roc_auc,
    delta_roc         = roc_auc - cv_roc_auc,
    optimal_threshold = optimal_threshold
  )


# ── Nettoyage de l'environnement ─────────────────────────────────────────────

rm(list = setdiff(ls(), c(
  "data",
  "churn_split", "train_data", "test_data", "churn_folds",
  "recipe_tree", "recipe_xgb", "recipe_distance",
  "logit_spec", "tree_spec", "bagging_spec", "rf_spec", "xgb_spec",
  "knn_spec", "svm_lin_spec", "svm_rad_spec",
  "all_workflows", "churn_metrics", "benchmark_results",
  "predictions_cv", "palette_modeles", "race_ctrl",
  "xgb_tune_spec", "xgb_tune_wflow",
  "xgb_grid_p1", "xgb_tune_results", "xgb_best_p1",
  "xgb_grid_p2", "xgb_zoom_results", "xgb_best_params",
  "xgb_final_wflow", "xgb_fit_train",
  "xgb_last_fit", "test_metrics", "test_predictions",
  "cv_vs_test", "summary_table",
  "conf_mat_data", "threshold_analysis", "optimal_threshold",
  "plot_xgb_tuning", "plot_xgb_zoom", "plot_xgb_importance",
  "plot_confusion_matrix", "plot_roc_curve",
  "plot_prob_distribution", "plot_threshold_analysis",
  "tableau_metriques",
  "plot_benchmark_roc", "plot_roc_curves", "plot_metrics_heatmap",
  "plot_conf_matrices", "plot_benchmark_all",
  "tableau_presentation_donnees",
  "tableau_summary_num", "tableau_summary_cat",
  "plot_desequilibre", "plot_dist_num", "plot_boxplot_churn",
  "plot_correlation", "plot_cat_churn",
  "couleurs_churn"
)))