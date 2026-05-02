# Ce script produit l'ensemble des visualisations et tableaux de comparaison
# du benchmark initial. Il est conçu pour être sourcé après 05_benchmark_initial.R
# ou chargé de manière autonome via le fichier .rds persisté.
#
# Prérequis : benchmark_results (workflow_set avec save_pred = TRUE)
#
# Objets exportés :
#   Tableaux   : tableau_metriques
#   Graphiques : plot_benchmark_roc, plot_roc_curves, plot_metrics_heatmap,
#                plot_conf_matrices

source("script/_utils.R")


# ── 0. Chargement des résultats si nécessaire ────────────────────────────────

if (!exists("benchmark_results")) {
  benchmark_results <- readRDS("data/benchmark_results_churn.rds")
}



# ── 1. Tableau récapitulatif des métriques ───────────────────────────────────
#
# Résumé lisible de toutes les métriques pour chaque modèle,
# trié par ROC AUC décroissant.

tableau_metriques <- benchmark_results |>
  collect_metrics() |>
  filter(.metric %in% c("roc_auc", "f_meas", "precision", "recall", "accuracy")) |>
  select(wflow_id, .metric, mean, std_err) |>
  mutate(
    valeur = paste0(
      round(mean * 100, 2), "%",
      " ± ", round(std_err * 100, 2), "%"
    )
  ) |>
  select(wflow_id, .metric, valeur) |>
  pivot_wider(names_from = .metric, values_from = valeur) |>
  # Tri par ROC AUC : extraction de la valeur numérique pour le tri
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
    align    = c("l", rep("c", 5))
  ) |>
  kable_styling(
    latex_options = c("striped", "hold_position", "scale_down"),
    font_size     = 9
  )


# ── 2. Classement par ROC AUC ────────────────────────────────────────────────
#
# Graphique en points avec IC à 95 %, trié par performance.

plot_benchmark_roc <- benchmark_results |>
  rank_results(rank_metric = "roc_auc", select_best = TRUE) |>
  filter(.metric == "roc_auc") |>
  mutate(wflow_id = fct_reorder(wflow_id, mean)) |>
  ggplot(aes(x = mean, y = wflow_id, colour = wflow_id)) +
  # On réduit la taille des points et l'épaisseur pour le minimalisme
  geom_errorbar(
    aes(xmin = mean - 1.96 * std_err, xmax = mean + 1.96 * std_err),
    width = 0, # Supprime les barres perpendiculaires aux extrémités
    alpha = 0.5,
    linewidth = 0.8,
    show.legend = FALSE
  ) +
  geom_point(size = 2.5, show.legend = FALSE) +
  scale_colour_manual(values = palette_modeles) +
  scale_x_continuous(labels = scales::label_percent()) +
  labs(x = NULL, y = NULL) +
  theme_minimal(base_size = 10) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(), # Garde uniquement les lignes verticales pour comparer les scores
  )


# ── 3. Courbes ROC par modèle ────────────────────────────────────────────────
#
# Chaque courbe est construite à partir des probabilités prédites
# agrégées sur les 10 folds (save_pred = TRUE dans 05).
# Une courbe proche du coin supérieur gauche indique une excellente
# discrimination.

predictions_cv <- benchmark_results |>
  collect_predictions()

plot_roc_curves <- predictions_cv |>
  group_by(wflow_id) |>
  roc_curve(truth = Churn, .pred_Yes, event_level = "second") |>
  ggplot(aes(x = 1 - specificity, y = sensitivity, colour = wflow_id)) +
  # Diagonale de référence (modèle aléatoire)
  geom_abline(linetype = "dotted", colour = "grey70", linewidth = 0.5) +
  geom_line(linewidth = 0.8, alpha = 0.9) +
  scale_colour_manual(values = palette_modeles) +
  # On réduit les marges blanches autour des courbes
  scale_x_continuous(labels = scales::label_percent(), expand = c(0.01, 0.01)) +
  scale_y_continuous(labels = scales::label_percent(), expand = c(0.01, 0.01)) +
  # Force le ratio 1:1 pour une lecture honnête de l'AUC
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


# ── 4. Heatmap des métriques ─────────────────────────────────────────────────
#
# Vue synthétique : chaque cellule = score moyen, couleur = niveau relatif.
# Permet d'identifier d'un coup d'œil les modèles avec un profil équilibré
# versus ceux qui excellent sur une métrique au détriment d'une autre.

metriques_long <- benchmark_results |>
  collect_metrics() |>
  filter(.metric %in% c("roc_auc", "f_meas", "precision", "recall", "accuracy")) |>
  mutate(
    # Normalisation par métrique pour une lecture relative
    .metric = factor(.metric, levels = c("roc_auc", "f_meas", "recall", "precision", "accuracy"))
  )

plot_metrics_heatmap <- metriques_long |>
  ggplot(aes(x = .metric, y = fct_reorder(wflow_id, mean), fill = mean)) +
  geom_tile(colour = "white", linewidth = 0.6) +
  geom_text(
    aes(label = round(mean * 100, 1)),
    size = 3, colour = "white", fontface = "bold"
  ) +
  scale_fill_gradient(
    low = "#185FA5",
    high = "#A32D2D",
    name = "Score\nmoyen",
    labels = scales::label_percent()
  ) +
  labs(
    title    = "Heatmap des métriques par modèle",
    subtitle = "Valeurs en % – triées par ROC AUC moyen",
    x        = NULL,
    y        = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title   = element_text(face = "bold"),
    panel.grid   = element_blank(),
    axis.text.x  = element_text(size = 10)
  )


# ── 5. Matrices de confusion agrégées ───────────────────────────────────────
#
# Matrices construites sur l'ensemble des prédictions CV agrégées.
# Révèle le type d'erreurs dominant : faux positifs (churn prédit à tort)
# vs faux négatifs (churn non détecté — souvent plus coûteux).
#
# Note technique : tidy.conf_mat() retourne les cellules sous la forme
# "cell_R_C" où R = indice ligne (prédit) et C = indice colonne (réel),
# dans l'ordre colonne-major : (1,1), (2,1), (1,2), (2,2).
# Les niveaux de Churn étant c("No", "Yes"), l'indice 1 = "No", 2 = "Yes".

plot_conf_matrices <- predictions_cv |>
  group_by(wflow_id) |>
  conf_mat(truth = Churn, estimate = .pred_class) |>
  mutate(tidied = map(conf_mat, tidy)) |>
  unnest(tidied) |>
  separate(name, into = c("prefix", "pred_idx", "truth_idx"), sep = "_") |>
  mutate(
    pred_class = c("No", "Yes")[as.integer(pred_idx)],
    truth_class = c("No", "Yes")[as.integer(truth_idx)],
    cell_type = case_when(
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
      label = paste0(cell_type, "\n", value),
      # Le texte devient noir sur les cases claires et blanc sur les cases foncées
      colour = value > (max(value) / 2)
    ),
    size = 2.8, fontface = "bold", show.legend = FALSE
  ) +
  facet_wrap(~wflow_id, ncol = 4) +
  # Utilisation de la palette bleue cohérente avec tes autres graphiques
  scale_fill_gradient(low = "#E3F2FD", high = "#185FA5") +
  scale_colour_manual(values = c("TRUE" = "white", "FALSE" = "grey20")) +
  coord_equal() +
  labs(
    x = "Réel",
    y = "Prédit",
    fill = NULL
  ) +
  theme_minimal(base_size = 9) +
  theme(
    panel.grid = element_blank(),
    strip.text = element_text(face = "bold", size = 8),
    legend.position = "none" # On enlève la légende pour épurer
  )


# ── Nettoyage de l'environnement ─────────────────────────────────────────────

rm(list = setdiff(ls(), c(
  "data",
  "churn_split",
  "train_data",
  "test_data",
  "churn_folds",
  "recipe_tree",
  "recipe_xgb",
  "recipe_distance",
  "recipe_lda_qda",
  "logit_spec",
  "tree_spec",
  "bagging_spec",
  "rf_spec",
  "xgb_spec",
  "knn_spec",
  "svm_lin_spec",
  "svm_rad_spec",
  "lda_spec",
  "qda_spec",
  "all_workflows",
  "churn_metrics",
  "benchmark_results",
  "predictions_cv",
  "palette_modeles",
  "tableau_metriques",
  "plot_benchmark_roc",
  "plot_roc_curves",
  "plot_metrics_heatmap",
  "plot_conf_matrices",
  "plot_benchmark_all",
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
