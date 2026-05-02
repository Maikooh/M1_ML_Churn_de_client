library(tidymodels)
library(finetune)
library(xgboost)
library(future)
library(doFuture)


# ── 0. Sourcing ──────────────────────────────────────────────────────────────

if (!exists("train_data")) {
  source("script/00_presentation_des_donnees.R")
  source("script/01_analyse_exploratoire.R")
  source("script/02_echantillon_et_recipe.R")
  source("script/03_model_spec.R")
  source("script/04_workflow.R")
}

options(yardstick.event_first = FALSE)
churn_metrics <- metric_set(roc_auc, f_meas, precision, recall)


# ── 1. Spécification XGBoost avec tune() ─────────────────────────────────────

xgb_tune_spec <- boost_tree(
  trees          = tune(),
  tree_depth     = tune(),
  learn_rate     = tune(),
  min_n          = tune(),
  loss_reduction = tune(),
  sample_size    = tune(),
  mtry           = tune()
) |>
  set_engine("xgboost") |>
  set_mode("classification")


# ── 2. Workflow ──────────────────────────────────────────────────────────────

xgb_tune_wflow <- workflow() |>
  add_recipe(recipe_xgb) |>
  add_model(xgb_tune_spec)


# ── 3. Configuration parallèle ───────────────────────────────────────────────

plan(multisession, workers = parallel::detectCores() - 1)
registerDoFuture()
on.exit(plan(sequential), add = TRUE)

race_ctrl <- control_race(
  verbose       = TRUE,
  save_pred     = TRUE,
  parallel_over = "everything"
)


# ── 4. Phase 1 : exploration large (Latin Hypercube, 50 combinaisons) ────────

xgb_grid_p1 <- grid_latin_hypercube(
  trees(range          = c(50L, 800L)),
  tree_depth(range     = c(1L, 5L)),
  learn_rate(range     = c(-3, -1)),
  min_n(range          = c(2L, 20L)),
  loss_reduction(range = c(-5, 0)),
  sample_size          = sample_prop(range = c(0.5, 1.0)),
  mtry(range           = c(3L, 13L)),
  size = 50
)

rds_p1 <- "data/xgb_tune_p1.rds"

if (file.exists(rds_p1)) {
  message("Chargement passe 1 depuis ", rds_p1)
  xgb_tune_results <- readRDS(rds_p1)
} else {
  set.seed(2026)
  xgb_tune_results <- xgb_tune_wflow |>
    tune_race_anova(
      resamples = churn_folds,
      grid      = xgb_grid_p1,
      metrics   = churn_metrics,
      control   = race_ctrl
    )
  saveRDS(xgb_tune_results, rds_p1)
  message("Sauvegardé dans ", rds_p1)
}

xgb_best_p1 <- select_best(xgb_tune_results, metric = "roc_auc")


# ── 5. Phase 2 : zoom local (grille resserrée, 40 combinaisons) ──────────────

xgb_grid_p2 <- grid_latin_hypercube(
  trees(range          = c(400L, 900L)),
  tree_depth(range     = c(3L, 6L)),
  learn_rate(range     = c(-1.25, -1.1)),
  min_n(range          = c(5L, 7L)),
  loss_reduction(range = c(-2.0, -1.65)),
  sample_size          = sample_prop(range = c(0.9, 1.0)),
  mtry(range           = c(5L, 10L)),
  size = 40
)

rds_p2 <- "data/xgb_tune_p2.rds"

if (file.exists(rds_p2)) {
  message("Chargement passe 2 depuis ", rds_p2)
  xgb_zoom_results <- readRDS(rds_p2)
} else {
  set.seed(2026)
  xgb_zoom_results <- xgb_tune_wflow |>
    tune_race_anova(
      resamples = churn_folds,
      grid      = xgb_grid_p2,
      metrics   = churn_metrics,
      control   = race_ctrl
    )
  saveRDS(xgb_zoom_results, rds_p2)
  message("Sauvegardé dans ", rds_p2)
}

xgb_best_params <- select_best(xgb_zoom_results, metric = "roc_auc")
xgb_final_wflow <- finalize_workflow(xgb_tune_wflow, xgb_best_params)


# ── 6. Visualisations ────────────────────────────────────────────────────────

# Phase 1 : évolution par hyperparamètre
plot_xgb_tuning <- xgb_tune_results |>
  collect_metrics() |>
  filter(.metric == "roc_auc") |>
  pivot_longer(
    c(trees, tree_depth, learn_rate, min_n, loss_reduction, sample_size, mtry),
    names_to = "parametre", values_to = "valeur"
  ) |>
  ggplot(aes(x = valeur, y = mean)) +
  geom_point(alpha = 0.5, size = 1.2, colour = "#E24B4A") +
  geom_smooth(method = "loess", span = 1.2, se = FALSE,
              linewidth = 0.7, colour = "#A32D2D") +
  facet_wrap(~parametre, scales = "free_x", ncol = 4) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(NA, 1)) +
  labs(
    title    = "Tuning XGBoost — Phase 1 (exploration)",
    subtitle = "ROC AUC selon les hyperparamètres",
    x        = "Valeur de l'hyperparamètre",
    y        = "ROC AUC moyen (CV)"
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"))

# Phase 2 : zoom local
plot_xgb_zoom <- xgb_zoom_results |>
  collect_metrics() |>
  filter(.metric == "roc_auc") |>
  pivot_longer(
    c(trees, tree_depth, learn_rate, min_n, loss_reduction, sample_size, mtry),
    names_to = "parametre", values_to = "valeur"
  ) |>
  ggplot(aes(x = valeur, y = mean)) +
  geom_point(alpha = 0.6, size = 2, colour = "#8E44AD") +
  geom_smooth(method = "loess", span = 1.5, se = FALSE,
              linewidth = 0.8, colour = "#5B2C6F") +
  facet_wrap(~parametre, scales = "free_x", ncol = 4) +
  scale_y_continuous(labels = scales::percent_format(), limits = c(NA, 1)) +
  labs(
    title    = "Tuning XGBoost — Phase 2 (zoom)",
    subtitle = "ROC AUC selon les hyperparamètres (grille resserrée)",
    x        = "Valeur de l'hyperparamètre",
    y        = "ROC AUC moyen (CV)"
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"))


# ── 7. Importance des variables ──────────────────────────────────────────────

xgb_fit_train <- xgb_final_wflow |> fit(data = train_data)

plot_xgb_importance <- xgb_fit_train |>
  extract_fit_parsnip() |>
  vip::vip(
    num_features = 13,
    aesthetics   = list(fill = "#E24B4A", colour = "white", width = 0.7)
  ) +
  labs(
    title    = "Importance des variables — XGBoost",
    subtitle = "Gain moyen sur le train set",
    x        = NULL,
    y        = "Importance"
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"))


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
  "plot_xgb_tuning", "plot_xgb_zoom", "plot_xgb_importance",
  "tableau_metriques",
  "plot_benchmark_roc", "plot_roc_curves", "plot_metrics_heatmap",
  "plot_conf_matrices", "plot_benchmark_all",
  "tableau_presentation_donnees",
  "tableau_summary_num", "tableau_summary_cat",
  "plot_desequilibre", "plot_dist_num", "plot_boxplot_churn",
  "plot_correlation", "plot_cat_churn",
  "couleurs_churn"
)))