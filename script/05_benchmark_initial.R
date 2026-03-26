# Ce fichier contient le benchmark des premiers modèles.
#


# lancer les script précédents
exec_precedent <- T

if (exec_precedent) {
  source("script/00_presentation_des_donnees.R")
  source("script/01_analyse_exploratoire.R")
  source("script/02_echantillon_et_recipe.R")
  source("script/03_model_spec.R")
  source("script/04_workflow.R")
}


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
      control = control_resamples(save_pred = TRUE),
      verbose = TRUE
    )
)


plan(sequential)

saveRDS(benchmark_results, "data/benchmark_results_churn.rds")

rank_results(benchmark_results, rank_metric = "roc_auc", select_best = TRUE)
autoplot(benchmark_results)

# NOTE : CERTAINS MODELES NE FONCTIONNENT PAS DONC A FIX -> suppression du modèle lda
# et du modèle qda qui ne sont pas adapté au problème donc à justifier dans le rapport
