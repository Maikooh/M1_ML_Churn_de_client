library(tidymodels)
library(future)
library(doFuture)


# ── 0. Sourcing des scripts précédents ───────────────────────────────────────

source("script/00_presentation_des_donnees.R")
source("script/01_analyse_exploratoire.R")
source("script/02_echantillon_et_recipe.R")
source("script/03_model_spec.R")
source("script/04_workflow.R")


# ── 1. Classe positive sur "Yes" ─────────────────────────────────────────────
# Par défaut yardstick place "No" en premier — on bascule sur "Yes"
# pour que precision/recall/f_meas mesurent la détection du churn

options(yardstick.event_first = FALSE)


# ── 2. Métriques d'évaluation ────────────────────────────────────────────────
# accuracy conservée pour comparaison, à interpréter avec prudence (~16 % Yes)

churn_metrics <- metric_set(roc_auc, f_meas, precision, recall, accuracy)


# ── 3. Benchmark par validation croisée ──────────────────────────────────────

rds_path <- "data/benchmark_results_churn.rds"

if (file.exists(rds_path)) {
  message("Chargement des résultats existants depuis ", rds_path)
  benchmark_results <- readRDS(rds_path)
} else {
  plan(multisession, workers = parallel::detectCores() - 1)
  registerDoFuture()
  on.exit(plan(sequential), add = TRUE)
  
  set.seed(2026)
  
  system.time(
    benchmark_results <- all_workflows |>
      workflow_map(
        fn        = "fit_resamples",
        resamples = churn_folds,
        metrics   = churn_metrics,
        control   = control_resamples(save_pred = TRUE, verbose = TRUE)
      )
  )
  
  saveRDS(benchmark_results, rds_path)
  message("Résultats sauvegardés dans ", rds_path)
}


# ── 4. Visualisation des résultats ───────────────────────────────────────────

# Classement par ROC AUC
plot_benchmark_roc <- benchmark_results |>
  rank_results(rank_metric = "roc_auc", select_best = TRUE) |>
  mutate(wflow_id = fct_reorder(wflow_id, mean)) |>
  filter(.metric == "roc_auc") |>
  ggplot(aes(x = mean, y = wflow_id)) +
  geom_point(size = 3, colour = "#185FA5") +
  geom_errorbar(
    aes(xmin = mean - 1.96 * std_err, xmax = mean + 1.96 * std_err),
    width = 0.25, colour = "#185FA5", alpha = 0.6, orientation = "y"
  ) +
  labs(
    title    = "Benchmark initial - classement par ROC AUC",
    subtitle = "Moyenne ± 1.96 x erreur standard sur 10 folds",
    x        = "ROC AUC",
    y        = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"))

# Toutes les métriques
plot_benchmark_all <- autoplot(
  benchmark_results,
  metric = c("roc_auc", "f_meas", "precision", "recall")
)


# ── Nettoyage de l'environnement ─────────────────────────────────────────────

rm(list = setdiff(ls(), c(
  "data",
  "churn_split", "train_data", "test_data", "churn_folds",
  "recipe_tree", "recipe_xgb", "recipe_distance",
  "logit_spec", "tree_spec", "bagging_spec", "rf_spec", "xgb_spec",
  "knn_spec", "svm_lin_spec", "svm_rad_spec",
  "all_workflows", "churn_metrics", "benchmark_results",
  "plot_benchmark_roc", "plot_benchmark_all",
  "tableau_presentation_donnees",
  "tableau_summary_num", "tableau_summary_cat",
  "plot_desequilibre", "plot_dist_num", "plot_boxplot_churn",
  "plot_correlation", "plot_cat_churn",
  "couleurs_churn"
)))