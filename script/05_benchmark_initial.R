# Ce fichier contient le benchmark des premiers modèles.
#


library(future)
library(doFuture)

plan(multisession, workers = parallel::detectCores() - 1)
registerDoFuture()

# Définition des métriques de succès
churn_metrics <- metric_set(roc_auc, f_meas, accuracy, precision, recall)

# Lancement du calcul
set.seed(2026)

system.time(
  benchmark_results <- all_workflows %>%
    workflow_map(
      fn = "fit_resamples",
      resamples = churn_folds,
      metrics = churn_metrics,
      verbose = TRUE
    )
)


plan(sequential)

saveRDS(benchmark_results, "data/benchmark_results_churn.rds")

rank_results(benchmark_results, rank_metric = "roc_auc", select_best = TRUE)
autoplot(benchmark_results, metric = "roc_auc")

# NOTE : CERTAINS MODELES NE FONCTIONNENT PAS DONC A FIX