# ══════════════════════════════════════════════════════════════════════════════
# 08_comparaison_tuning.R
# ══════════════════════════════════════════════════════════════════════════════
#
# Ce script produit l'ensemble des visualisations et tableaux de comparaison
# des résultats de tuning. Il permet d'analyser :
#   - Le classement des modèles après optimisation
#   - Les meilleurs hyperparamètres trouvés
#   - Les courbes ROC comparatives
#   - L'évolution des performances pendant le tuning
#   - Les matrices de confusion
#
# Prérequis : tuning_results (issu de 07_tuning.R)
#
# Objets exportés :
#   Tableaux   : tableau_tuning_metrics, tableau_best_params
#   Graphiques : plot_tuning_ranking, plot_tuning_roc, plot_tuning_heatmap,
#                plot_tuning_evolution, plot_tuning_conf_matrices

library(tidymodels)
library(knitr)
library(kableExtra)
library(patchwork) # composition de graphiques
library(ggrepel)

# ── 0. Chargement des résultats si nécessaire ────────────────────────────────

if (!exists("tuning_results")) {
  tuning_results <- readRDS("data/tuning_results_churn.rds")
}

options(yardstick.event_first = FALSE)

# Palette commune pour les modèles
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

# Noms lisibles pour les modèles
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


# ══════════════════════════════════════════════════════════════════════════════
# 1. TABLEAU RÉCAPITULATIF DES MÉTRIQUES (MEILLEURE CONFIG PAR MODÈLE)
# ══════════════════════════════════════════════════════════════════════════════

tuning_metrics_df <- tuning_results |>
  rank_results(rank_metric = "roc_auc", select_best = TRUE) |>
  filter(.metric %in% c("roc_auc", "f_meas", "precision", "recall", "accuracy")) |>
  select(wflow_id, .metric, mean, std_err)

tableau_tuning_metrics <- tuning_metrics_df |>
  mutate(
    valeur = paste0(
      sprintf("%.2f", mean * 100), "%",
      " ± ", sprintf("%.2f", std_err * 100), "%"
    )
  ) |>
  select(wflow_id, .metric, valeur) |>
  pivot_wider(names_from = .metric, values_from = valeur) |>
  left_join(
    tuning_metrics_df |>
      filter(.metric == "roc_auc") |>
      select(wflow_id, mean),
    by = "wflow_id"
  ) |>
  arrange(desc(mean)) |>
  select(-mean) |>
  mutate(Modèle = noms_modeles[wflow_id]) |>
  select(Modèle, roc_auc, f_meas, recall, precision, accuracy) |>
  rename(
    `ROC AUC` = roc_auc,
    `F1-Score` = f_meas,
    Recall = recall,
    Precision = precision,
    Accuracy = accuracy
  ) |>
  kable(
    booktabs = TRUE,
    align = c("l", rep("c", 5))
  ) |>
  kable_styling(
    latex_options = c("striped", "hold_position", "scale_down"),
    font_size = 9
  )


# ══════════════════════════════════════════════════════════════════════════════
# 2. TABLEAU DES MEILLEURS HYPERPARAMÈTRES
# ══════════════════════════════════════════════════════════════════════════════

extract_best_config <- function(wflow_id) {
  result <- tuning_results |>
    extract_workflow_set_result(id = wflow_id)

  # Vérifier si c'est un résultat de tuning avec des hyperparamètres

  if (inherits(result, "tune_results") && nrow(collect_metrics(result)) > 0) {
    best <- select_best(result, metric = "roc_auc")
    # Retirer les colonnes internes (.config, .metric, etc.)
    params_df <- best |> select(-starts_with("."))

    # Vérifier s'il reste des colonnes d'hyperparamètres
    if (ncol(params_df) == 0) {
      return("Hyperparamètres par défaut")
    }

    # Convertir en chaîne lisible
    params <- params_df |>
      pivot_longer(everything(), names_to = "param", values_to = "value") |>
      mutate(value = round(value, 4)) |>
      summarise(config = paste(param, "=", value, collapse = ", ")) |>
      pull(config)
    return(params)
  } else {
    return("Pas de tuning")
  }
}

tableau_best_params <- tibble(
  wflow_id = tuning_results$wflow_id
) |>
  mutate(
    Modèle = noms_modeles[wflow_id],
    Hyperparamètres = map_chr(wflow_id, extract_best_config)
  ) |>
  left_join(
    tuning_results |>
      rank_results(rank_metric = "roc_auc", select_best = TRUE) |>
      filter(.metric == "roc_auc") |>
      select(wflow_id, mean),
    by = "wflow_id"
  ) |>
  arrange(desc(mean)) |>
  select(Modèle, Hyperparamètres, `ROC AUC` = mean) |>
  mutate(`ROC AUC` = sprintf("%.2f%%", `ROC AUC` * 100)) |>
  kable(
    booktabs = TRUE,
    align = c("l", "l", "c")
  ) |>
  kable_styling(
    latex_options = c("striped", "hold_position", "scale_down"),
    font_size = 9
  )


# ══════════════════════════════════════════════════════════════════════════════
# 3. CLASSEMENT PAR ROC AUC (GRAPHIQUE)
# ══════════════════════════════════════════════════════════════════════════════

plot_tuning_ranking <- tuning_results |>
  rank_results(rank_metric = "roc_auc", select_best = TRUE) |>
  filter(.metric == "roc_auc") |>
  mutate(wflow_id = fct_reorder(wflow_id, mean)) |>
  ggplot(aes(x = mean, y = wflow_id, colour = wflow_id)) +
  geom_errorbar(
    aes(xmin = mean - 1.96 * std_err, xmax = mean + 1.96 * std_err),
    width = 0, alpha = 0.5, linewidth = 0.8, show.legend = FALSE
  ) +
  geom_point(size = 3, show.legend = FALSE) +
  geom_vline(xintercept = 0.95, linetype = "dotted", colour = "grey80") +
  scale_colour_manual(values = palette_modeles) +
  scale_x_continuous(
    labels = scales::label_percent(accuracy = 1),
    limits = c(0.90, 1.0),
    breaks = seq(0.90, 1.0, 0.02)
  ) +
  scale_y_discrete(labels = noms_modeles) +
  labs(x = NULL, y = NULL) + # Tous les titres sont supprimés
  theme_minimal(base_size = 10) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(),
    axis.text.y = element_text(face = "bold", size = 9),
    axis.text.x = element_text(colour = "grey50")
  )


# ══════════════════════════════════════════════════════════════════════════════
# 4. COURBES ROC COMPARATIVES
# ══════════════════════════════════════════════════════════════════════════════

# Collecter les prédictions de la meilleure config par modèle.
# tuning_results est un bind_rows() de tune_results ET resample_results.
# collect_predictions(select_best = TRUE) n'est défini que pour tune_results ;
# appelé sur des resample_results, son comportement peut varier selon la
# version de {tune}. On sépare donc explicitement les deux cas.

modeles_tunes <- c(
  "tree_rf", "tree_dt", "xgb_xgb",
  "dist_knn", "dist_svm_lin", "dist_svm_rad"
)
modeles_fixes <- c("tree_bag", "dist_logit", "discrim_lda", "discrim_qda")

predictions_tuning <- bind_rows(
  tuning_results |>
    filter(wflow_id %in% modeles_tunes) |>
    collect_predictions(select_best = TRUE),
  tuning_results |>
    filter(wflow_id %in% modeles_fixes) |>
    collect_predictions()
)

plot_tuning_roc <- predictions_tuning |>
  group_by(wflow_id) |>
  roc_curve(truth = Churn, .pred_Yes, event_level = "second") |>
  ggplot(aes(x = 1 - specificity, y = sensitivity, colour = wflow_id)) +
  # Diagonale de référence
  geom_abline(linetype = "dotted", colour = "grey70", linewidth = 0.5) +
  geom_line(linewidth = 0.8, alpha = 0.9) +
  scale_colour_manual(values = palette_modeles, labels = noms_modeles) +
  # Optimisation de l'espace et des axes
  scale_x_continuous(labels = scales::label_percent(), expand = c(0.01, 0.01)) +
  scale_y_continuous(labels = scales::label_percent(), expand = c(0.01, 0.01)) +
  coord_equal() +
  labs(
    x = "Taux de faux positifs",
    y = "Taux de vrais positifs",
    colour = NULL
  ) +
  theme_minimal(base_size = 10) +
  theme(
    panel.grid.minor = element_blank(),
    legend.position = "right",
    axis.title = element_text(size = 9, colour = "grey30")
  )


# ══════════════════════════════════════════════════════════════════════════════
# 5. HEATMAP DES MÉTRIQUES
# ══════════════════════════════════════════════════════════════════════════════

plot_tuning_heatmap <- tuning_metrics_df |>
  mutate(
    .metric = factor(
      .metric,
      levels = c("roc_auc", "f_meas", "recall", "precision", "accuracy"),
      labels = c("ROC AUC", "F1-Score", "Recall", "Precision", "Accuracy")
    ),
    nom = noms_modeles[as.character(wflow_id)]
  ) |>
  ggplot(aes(x = .metric, y = fct_reorder(nom, mean), fill = mean)) +
  geom_tile(colour = "white", linewidth = 0.8) +
  geom_text(
    aes(label = sprintf("%.1f", mean * 100)),
    size = 3.5, colour = "white", fontface = "bold"
  ) +
  scale_fill_gradient2(
    low = "#2166AC",
    mid = "#F7F7F7",
    high = "#B2182B",
    midpoint = 0.85,
    name = "Score",
    labels = scales::label_percent(),
    limits = c(0.7, 1)
  ) +
  labs(
    title = "Heatmap des métriques après tuning",
    subtitle = "Valeurs en % — Triées par ROC AUC",
    x = NULL,
    y = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(colour = "grey40"),
    panel.grid = element_blank(),
    axis.text.x = element_text(angle = 45, hjust = 1, size = 11)
  )


# ══════════════════════════════════════════════════════════════════════════════
# 6. ÉVOLUTION DES PERFORMANCES PENDANT LE TUNING (MODÈLES TUNÉS UNIQUEMENT)
# ══════════════════════════════════════════════════════════════════════════════

# Extraire les résultats détaillés pour les modèles tunés
modeles_tunes <- c("tree_rf", "tree_dt", "xgb_xgb", "dist_knn", "dist_svm_lin", "dist_svm_rad")

plot_tuning_evolution <- tuning_results |>
  filter(wflow_id %in% modeles_tunes) |>
  mutate(
    metrics = map(result, collect_metrics)
  ) |>
  select(wflow_id, metrics) |>
  unnest(metrics) |>
  filter(.metric == "roc_auc") |>
  mutate(nom = noms_modeles[as.character(wflow_id)]) |>
  ggplot(aes(x = fct_reorder(nom, -mean, .fun = max), y = mean, fill = wflow_id)) +
  geom_boxplot(alpha = 0.7, show.legend = FALSE, outlier.alpha = 0.3) +
  geom_jitter(
    aes(colour = wflow_id),
    width = 0.2, alpha = 0.4, size = 1.5, show.legend = FALSE
  ) +
  scale_fill_manual(values = palette_modeles) +
  scale_colour_manual(values = palette_modeles) +
  scale_y_continuous(labels = scales::label_percent(), limits = c(0.7, 1)) +
  labs(
    title = "Distribution des ROC AUC pendant le tuning",
    subtitle = "Chaque point = une configuration testée | Boxplot = distribution",
    x = NULL,
    y = "ROC AUC"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(colour = "grey40"),
    axis.text.x = element_text(angle = 30, hjust = 1)
  )


# ══════════════════════════════════════════════════════════════════════════════
# 7. MATRICES DE CONFUSION (MEILLEURE CONFIG)
# ══════════════════════════════════════════════════════════════════════════════

plot_tuning_conf_matrices <- predictions_tuning |>
  mutate(nom = noms_modeles[as.character(wflow_id)]) |>
  group_by(wflow_id, nom) |>
  conf_mat(truth = Churn, estimate = .pred_class) |>
  mutate(tidied = map(conf_mat, tidy)) |>
  unnest(tidied) |>
  separate(name, into = c("prefix", "pred_idx", "truth_idx"), sep = "_") |>
  mutate(
    pred_class = c("No", "Yes")[as.integer(pred_idx)],
    truth_class = c("No", "Yes")[as.integer(truth_idx)],
    cell_label = case_when(
      pred_class == "No" & truth_class == "No" ~ "VN",
      pred_class == "Yes" & truth_class == "No" ~ "FP",
      pred_class == "No" & truth_class == "Yes" ~ "FN",
      pred_class == "Yes" & truth_class == "Yes" ~ "VP"
    )
  ) |>
  ggplot(aes(x = truth_class, y = pred_class, fill = value)) +
  geom_tile(colour = "white", linewidth = 0.5) +
  geom_text(
    aes(
      label = paste0(cell_label, "\n", value),
      colour = value > (max(value) / 2)
    ),
    size = 2.8, fontface = "bold", show.legend = FALSE
  ) +
  facet_wrap(~nom, ncol = 4) +
  # Dégradé de bleu simple et efficace
  scale_fill_gradient(low = "#E3F2FD", high = "#185FA5") +
  scale_colour_manual(values = c("TRUE" = "white", "FALSE" = "grey20")) +
  coord_equal() +
  labs(x = "Réel", y = "Prédit") +
  theme_minimal(base_size = 9) +
  theme(
    panel.grid = element_blank(),
    strip.text = element_text(face = "bold"),
    legend.position = "none" # On masque la légende pour un look ultra-clean
  )


# ══════════════════════════════════════════════════════════════════════════════
# 8. COMPARAISON PRECISION VS RECALL
# ══════════════════════════════════════════════════════════════════════════════

plot_precision_recall <- tuning_metrics_df |>
  filter(.metric %in% c("precision", "recall")) |>
  select(wflow_id, .metric, mean) |>
  pivot_wider(names_from = .metric, values_from = mean) |>
  mutate(nom = noms_modeles[as.character(wflow_id)]) |>
  ggplot(aes(x = recall, y = precision, colour = wflow_id)) +
  # Lignes de repère pour le "perfect score"
  geom_hline(yintercept = 1, linetype = "dotted", colour = "grey80") +
  geom_vline(xintercept = 1, linetype = "dotted", colour = "grey80") +
  # Points et étiquettes intelligentes
  geom_point(size = 3, alpha = 0.8, show.legend = FALSE) +
  geom_text_repel(
    aes(label = nom),
    size = 3.5,
    fontface = "bold",
    box.padding = 0.5,
    max.overlaps = Inf,
    show.legend = FALSE
  ) +
  scale_colour_manual(values = palette_modeles) +
  # Zoom sur la zone de haute performance
  scale_x_continuous(
    labels = scales::label_percent(),
    limits = c(0.80, 1.01),
    breaks = seq(0.8, 1, 0.05)
  ) +
  scale_y_continuous(
    labels = scales::label_percent(),
    limits = c(0.80, 1.01),
    breaks = seq(0.8, 1, 0.05)
  ) +
  coord_equal() + # Pour que 1% en X vaille 1% en Y
  labs(x = "Recall", y = "Précision") +
  theme_minimal(base_size = 10) +
  theme(
    panel.grid.minor = element_blank(),
    axis.title = element_text(colour = "grey30")
  )


# ══════════════════════════════════════════════════════════════════════════════
# 9. SYNTHÈSE : TOP 3 MODÈLES
# ══════════════════════════════════════════════════════════════════════════════

top3_models <- tuning_results |>
  rank_results(rank_metric = "roc_auc", select_best = TRUE) |>
  filter(.metric == "roc_auc") |>
  slice_max(mean, n = 3) |>
  pull(wflow_id)

message("\n", strrep("═", 60))
message("TOP 3 MODÈLES APRÈS TUNING")
message(strrep("═", 60), "\n")

for (i in seq_along(top3_models)) {
  wf <- top3_models[i]
  metrics <- tuning_metrics_df |>
    filter(wflow_id == wf) |>
    mutate(display = paste0(.metric, " = ", sprintf("%.2f%%", mean * 100)))

  message(i, ". ", noms_modeles[wf])
  message("   ", paste(metrics$display, collapse = " | "))
  message("   Config: ", extract_best_config(wf))
  message("")
}


# ══════════════════════════════════════════════════════════════════════════════
# 10. COMPOSITION FINALE (DASHBOARD)
# ══════════════════════════════════════════════════════════════════════════════

plot_dashboard_tuning <- (plot_tuning_ranking | plot_tuning_heatmap) /
  (plot_tuning_roc | plot_precision_recall) +
  plot_annotation(
    title = "Synthèse des résultats de tuning",
    subtitle = "Comparaison des 10 modèles après optimisation des hyperparamètres",
    theme = theme(
      plot.title = element_text(face = "bold", size = 16),
      plot.subtitle = element_text(colour = "grey40", size = 12)
    )
  )


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
  "benchmark_results",
  "tuning_results",
  "best_params", "best_params_detail",
  "palette_modeles", "noms_modeles",
  "predictions_tuning",
  "tableau_metriques",
  "plot_benchmark_roc", "plot_roc_curves", "plot_conf_matrices",
  "tableau_tuning_metrics", "tableau_best_params",
  "plot_tuning_ranking", "plot_tuning_roc", "plot_tuning_heatmap",
  "plot_tuning_evolution", "plot_tuning_conf_matrices",
  "plot_precision_recall", "plot_dashboard_tuning",
  "top3_models",
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
