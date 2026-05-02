library(tidymodels)
library(knitr)
library(kableExtra)


# ── 0. Chargement des résultats si nécessaire ────────────────────────────────

if (!exists("benchmark_results")) {
  benchmark_results <- readRDS("data/benchmark_results_churn.rds")
}

palette_modeles <- c(
  "xgb_xgb"      = "#E24B4A",
  "tree_rf"       = "#378ADD",
  "tree_bag"      = "#1D9E75",
  "tree_dt"       = "#BA7517",
  "dist_logit"    = "#7F77DD",
  "dist_knn"      = "#D85A30",
  "dist_svm_lin"  = "#888780",
  "dist_svm_rad"  = "#D4537E"
)


# ── 1. Tableau récapitulatif des métriques ───────────────────────────────────
# Trié par ROC AUC décroissant

tableau_metriques <- benchmark_results |>
  collect_metrics() |>
  filter(.metric %in% c("roc_auc", "f_meas", "precision", "recall", "accuracy")) |>
  select(wflow_id, .metric, mean, std_err) |>
  mutate(
    valeur = paste0(round(mean * 100, 2), "% ± ", round(std_err * 100, 2), "%")
  ) |>
  select(wflow_id, .metric, valeur) |>
  pivot_wider(names_from = .metric, values_from = valeur) |>
  left_join(
    benchmark_results |>
      collect_metrics() |>
      filter(.metric == "roc_auc") |>
      select(wflow_id, mean),
    by = "wflow_id"
  ) |>
  arrange(desc(mean)) |>
  select(-mean) |>
  rename(Modèle = wflow_id) |>
  kable(
    booktabs = TRUE,
    caption  = "Comparaison des métriques de benchmark (moyenne ± erreur standard sur 10 folds)",
    align    = c("l", rep("c", 5))
  ) |>
  kable_styling(
    latex_options = c("striped", "hold_position", "scale_down"),
    font_size     = 9
  )


# ── 2. Classement par ROC AUC ────────────────────────────────────────────────

plot_benchmark_roc <- benchmark_results |>
  rank_results(rank_metric = "roc_auc", select_best = TRUE) |>
  filter(.metric == "roc_auc") |>
  mutate(wflow_id = fct_reorder(wflow_id, mean)) |>
  ggplot(aes(x = mean, y = wflow_id, colour = wflow_id)) +
  geom_point(size = 3, show.legend = FALSE) +
  geom_errorbar(
    aes(xmin = mean - 1.96 * std_err, xmax = mean + 1.96 * std_err),
    width = 0.25, alpha = 0.6, show.legend = FALSE, orientation = "y"
  ) +
  scale_colour_manual(values = palette_modeles) +
  scale_x_continuous(labels = scales::label_percent()) +
  labs(
    title    = "Classement des modèles par ROC AUC",
    subtitle = "Moyenne ± 1,96 × erreur standard sur 10 folds de validation croisée",
    x        = "ROC AUC",
    y        = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"))


# ── 3. Courbes ROC ───────────────────────────────────────────────────────────
# Probabilités agrégées sur les 10 folds (save_pred = TRUE)

predictions_cv <- benchmark_results |>
  collect_predictions()

plot_roc_curves <- predictions_cv |>
  group_by(wflow_id) |>
  roc_curve(truth = Churn, .pred_Yes, event_level = "second") |>
  ggplot(aes(x = 1 - specificity, y = sensitivity, colour = wflow_id)) +
  geom_line(linewidth = 0.75) +
  geom_abline(linetype = "dashed", colour = "grey60", linewidth = 0.4) +
  scale_colour_manual(values = palette_modeles, name = "Modèle") +
  scale_x_continuous(labels = scales::label_percent()) +
  scale_y_continuous(labels = scales::label_percent()) +
  labs(
    title    = "Courbes ROC – comparaison des modèles",
    subtitle = "Probabilités agrégées sur les 10 folds | Diagonale = classifieur aléatoire",
    x        = "1 – Spécificité (Taux de faux positifs)",
    y        = "Sensibilité (Recall)"
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"), legend.position = "right")


# ── 4. Heatmap des métriques ─────────────────────────────────────────────────

plot_metrics_heatmap <- benchmark_results |>
  collect_metrics() |>
  filter(.metric %in% c("roc_auc", "f_meas", "precision", "recall", "accuracy")) |>
  mutate(.metric = factor(.metric, levels = c("roc_auc", "f_meas", "recall", "precision", "accuracy"))) |>
  ggplot(aes(x = .metric, y = fct_reorder(wflow_id, mean), fill = mean)) +
  geom_tile(colour = "white", linewidth = 0.6) +
  geom_text(aes(label = round(mean * 100, 1)), size = 3, colour = "white", fontface = "bold") +
  scale_fill_gradient(
    low = "#185FA5", high = "#A32D2D",
    name = "Score\nmoyen", labels = scales::label_percent()
  ) +
  labs(
    title    = "Heatmap des métriques par modèle",
    subtitle = "Valeurs en % – triées par ROC AUC moyen",
    x        = NULL,
    y        = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"), panel.grid = element_blank(),
        axis.text.x = element_text(size = 10))


# ── 5. Matrices de confusion agrégées ────────────────────────────────────────

plot_conf_matrices <- predictions_cv |>
  group_by(wflow_id) |>
  conf_mat(truth = Churn, estimate = .pred_class) |>
  mutate(tidied = map(conf_mat, tidy)) |>
  unnest(tidied) |>
  separate(name, into = c("Predicted", "Truth"), sep = "_") |>
  mutate(
    Predicted = factor(Predicted, levels = c("Cell1", "Cell2", "Cell3", "Cell4")),
    label = paste0(c("VN", "FP", "FN", "VP")[as.integer(Predicted)], "\n", value)
  ) |>
  mutate(
    pred_class  = rep(c("No", "No", "Yes", "Yes"), length.out = n()),
    truth_class = rep(c("No", "Yes", "No", "Yes"), length.out = n())
  ) |>
  ggplot(aes(x = truth_class, y = pred_class, fill = value)) +
  geom_tile(colour = "white") +
  geom_text(aes(label = value), size = 3, fontface = "bold", colour = "white") +
  facet_wrap(~wflow_id, ncol = 4) +
  scale_fill_gradient(low = "#B5D4F4", high = "#185FA5", name = "Effectif") +
  labs(
    title    = "Matrices de confusion agrégées (10 folds)",
    subtitle = "Lignes = Prédit | Colonnes = Réel",
    x        = "Churn réel",
    y        = "Churn prédit"
  ) +
  theme_minimal(base_size = 10) +
  theme(plot.title = element_text(face = "bold"), panel.grid = element_blank(),
        strip.text = element_text(size = 8))


# ── Nettoyage de l'environnement ─────────────────────────────────────────────

rm(list = setdiff(ls(), c(
  "data",
  "churn_split", "train_data", "test_data", "churn_folds",
  "recipe_tree", "recipe_xgb", "recipe_distance",
  "logit_spec", "tree_spec", "bagging_spec", "rf_spec", "xgb_spec",
  "knn_spec", "svm_lin_spec", "svm_rad_spec",
  "all_workflows", "churn_metrics", "benchmark_results",
  "predictions_cv", "palette_modeles",
  "tableau_metriques",
  "plot_benchmark_roc", "plot_roc_curves", "plot_metrics_heatmap",
  "plot_conf_matrices", "plot_benchmark_all",
  "tableau_presentation_donnees",
  "tableau_summary_num", "tableau_summary_cat",
  "plot_desequilibre", "plot_dist_num", "plot_boxplot_churn",
  "plot_correlation", "plot_cat_churn",
  "couleurs_churn"
)))