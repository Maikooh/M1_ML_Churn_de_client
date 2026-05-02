library(tidymodels)
library(ranger)
library(knitr)
library(kableExtra)


# ── 0. Sourcing ──────────────────────────────────────────────────────────────

source("script/00_presentation_des_donnees.R")
source("script/02_echantillon_et_recipe.R")

options(yardstick.event_first = FALSE)
churn_metrics <- metric_set(roc_auc, f_meas, precision, recall, accuracy)


# ── 1. Recette ───────────────────────────────────────────────────────────────

recipe_rf_opt <- recipe(Churn ~ ., data = train_data) |>
  step_impute_median(all_numeric_predictors()) |>
  step_impute_mode(all_nominal_predictors()) |>
  step_smotenc(Churn)


# ── 2. Spécification avec hyperparamètres optimaux ───────────────────────────

rf_spec_tuned <- rand_forest(mtry = 4, min_n = 11, trees = 1000) |>
  set_engine("ranger", importance = "permutation") |>
  set_mode("classification")


# ── 3. Workflow ──────────────────────────────────────────────────────────────

rf_final_wf <- workflow() |>
  add_recipe(recipe_rf_opt) |>
  add_model(rf_spec_tuned)


# ── 4. Évaluation finale sur le jeu de test ──────────────────────────────────

rf_final_fit <- last_fit(
  rf_final_wf,
  split   = churn_split,
  metrics = churn_metrics
)

rf_final_metrics <- collect_metrics(rf_final_fit)
rf_final_preds   <- collect_predictions(rf_final_fit)

rf_conf_mat <- rf_final_preds |>
  conf_mat(truth = Churn, estimate = .pred_class)


# ── 5. Importance des variables ──────────────────────────────────────────────

rf_variable_importance <- rf_final_fit |>
  extract_workflow() |>
  extract_fit_parsnip() |>
  pluck("fit") |>
  (\(fit) tibble(
    Variable   = names(fit$variable.importance),
    Importance = unname(fit$variable.importance)
  ))() |>
  arrange(desc(Importance))


# ── 6. Tableau comparaison CV vs test ────────────────────────────────────────

benchmark_results <- readRDS("data/benchmark_results_churn.rds")

tableau_comparaison_rf <- benchmark_results |>
  collect_metrics() |>
  filter(wflow_id == "tree_rf",
         .metric %in% c("roc_auc", "f_meas", "precision", "recall", "accuracy")) |>
  transmute(.metric, cv_initial = mean) |>
  left_join(
    rf_final_metrics |> select(.metric, test = .estimate),
    by = ".metric"
  ) |>
  mutate(across(c(cv_initial, test), \(x) paste0(round(x * 100, 2), "%"))) |>
  rename(Métrique = .metric, `CV initial` = cv_initial, `Test final` = test) |>
  kable(
    booktabs = TRUE,
    caption  = "Comparaison des performances du Random Forest : CV initial vs test final",
    align    = c("l", "c", "c")
  ) |>
  kable_styling(
    latex_options = c("striped", "hold_position"),
    font_size     = 9
  )


# ── Nettoyage de l'environnement ─────────────────────────────────────────────

rm(list = setdiff(ls(), c(
  "data",
  "churn_split", "train_data", "test_data", "churn_folds",
  "recipe_tree", "recipe_xgb", "recipe_distance",
  "logit_spec", "tree_spec", "bagging_spec", "rf_spec", "xgb_spec",
  "knn_spec", "svm_lin_spec", "svm_rad_spec",
  "all_workflows", "churn_metrics", "benchmark_results",
  "rf_final_wf", "rf_final_fit", "rf_final_metrics",
  "rf_final_preds", "rf_conf_mat", "rf_variable_importance",
  "tableau_comparaison_rf",
  "tableau_presentation_donnees",
  "tableau_summary_num", "tableau_summary_cat",
  "plot_desequilibre", "plot_dist_num", "plot_boxplot_churn",
  "plot_correlation", "plot_cat_churn",
  "couleurs_churn"
)))