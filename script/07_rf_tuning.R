#Ce script réalise le tuning du modèle random forest

# en suivant les recommendations
# de la documentation : https://www.tmwr.org/pre-proc-table.html

library(tidymodels)
library(ranger)

# ── 0. Sourcing ──────────────────────────────────────────────────────────────

source("script/00_presentation_des_donnees.R")
source("script/02_echantillon_et_recipe.R")

options(yardstick.event_first = FALSE)

churn_metrics <- metric_set(roc_auc, f_meas, precision, recall, accuracy)

# ── 1. Recipe RF : conforme TMWR ─────────────────────────────────────────────

recipe_rf_opt <- recipe(Churn ~ ., data = train_data) |> 
  step_impute_median(all_numeric_predictors()) |> 
  step_impute_mode(all_nominal_predictors()) |> 
  step_smotenc(Churn)

# ── 2. Spécification tunable RF ──────────────────────────────────────────────

rf_spec_tuned <- rand_forest(mtry  = tune(), min_n = tune(), trees = 1000) |> 
  set_engine("ranger", importance = "permutation") |> 
  set_mode("classification")

# ── 3. Workflow ──────────────────────────────────────────────────────────────

rf_wf_tuned <- workflow() |> 
  add_recipe(recipe_rf_opt) |> 
  add_model(rf_spec_tuned)

# ── 4. Grille ────────────────────────────────────────────────────────────────

rf_params <- parameters(mtry(), min_n()) |> 
  finalize(train_data |>  select(-Churn))

rf_grid <- grid_regular(rf_params, levels = 5)

# ── 5. Tuning CV ─────────────────────────────────────────────────────────────

set.seed(2026)

rf_tuning_results <- tune_grid(
  rf_wf_tuned,
  resamples = churn_folds,
  grid = rf_grid,
  metrics = churn_metrics,
  control = control_grid(save_pred = TRUE, verbose = TRUE))

# ── 6. Meilleurs paramètres ──────────────────────────────────────────────────

rf_best_params <- select_best(rf_tuning_results, metric = "roc_auc")
rf_best_table  <- show_best(rf_tuning_results, metric = "roc_auc", n = 10)

# ── 7. Modèle final ──────────────────────────────────────────────────────────

rf_final_wf <- finalize_workflow(rf_wf_tuned, rf_best_params)

rf_final_fit <- last_fit(
  rf_final_wf,
  split = churn_split,
  metrics = churn_metrics)

rf_final_metrics <- collect_metrics(rf_final_fit)
rf_final_preds   <- collect_predictions(rf_final_fit)

rf_conf_mat <- rf_final_preds |> 
  conf_mat(truth = Churn, estimate = .pred_class)

# ── 8. Importance des variables ──────────────────────────────────────────────

rf_engine <- rf_final_fit |> 
  extract_workflow() |> 
  extract_fit_parsnip() |> 
  pluck("fit")

rf_variable_importance <- tibble(
  Variable = names(rf_engine$variable.importance),
  Importance = unname(rf_engine$variable.importance)) |> 
  arrange(desc(Importance))

# ─────────────────────────────────────────────────────────────────────────────

rf_best_params
rf_best_table
rf_final_metrics
rf_conf_mat

# ────────── Comparaison avec rf_initiale ─────────────────────────────────────

benchmark_results <- readRDS("data/benchmark_results_churn.rds")

rf_initial_cv <- benchmark_results |> 
  collect_metrics() |> 
  filter(wflow_id == "tree_rf") |> 
  select(.metric, mean, std_err)

rf_tuned_cv <- rf_tuning_results |> 
  collect_metrics() |> 
  filter(mtry == 4, min_n == 11) |> 
  select(mtry, min_n, .metric, mean, std_err)


rf_initial_cv

rf_tuned_cv


# ─────────────────────────────────────────────────────────────────────────────


rf_initial_cv2 <- benchmark_results |> 
  collect_metrics() |> 
  filter(wflow_id == "tree_rf") |> 
  transmute(.metric, initial = mean)

rf_tuned_cv2 <- rf_tuning_results |> 
  collect_metrics() |> 
  filter(mtry == 4, min_n == 11) |> 
  transmute(.metric, tuned_cv = mean)

rf_compare <- rf_initial_cv2 |> 
  left_join(rf_tuned_cv2, by = ".metric") |> 
  mutate(gain = tuned_cv - initial)

rf_compare

# ─────────────────────────────────────────────────────────────────────────────

rf_test <- rf_final_metrics |> 
  select(.metric, test = .estimate)

rf_compare_full <- rf_compare |> 
  left_join(rf_test, by = ".metric")

rf_compare_full
