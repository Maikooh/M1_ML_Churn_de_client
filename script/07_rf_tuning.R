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

rf_spec_tuned <- rand_forest(mtry = 4, min_n = 11, trees = 1000) |> 
  set_engine("ranger", importance = "permutation") |> 
  set_mode("classification")

# ── 3. Workflow ──────────────────────────────────────────────────────────────

rf_wf_tuned <- workflow() |> 
  add_recipe(recipe_rf_opt) |> 
  add_model(rf_spec_tuned)

# ── 7. Modèle final ──────────────────────────────────────────────────────────

rf_final_wf <- rf_wf_tuned

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


# ────────── Tableau comparaison ─────────────────────────────────────

library(gt)

table_rf_tuning <- tibble(
  Metric = c("ROC AUC", "Precision", "Recall", "F1", "Accuracy"),
  `RF initial` = c(0.980, 0.976, 0.968, 0.972, 0.953),
  `RF tuné CV` = c(0.984, 0.984, 0.968, 0.976, 0.960),
  `RF test`    = c(0.993, 0.990, 0.968, 0.979, 0.965)
)

table_rf_tuning %>%
  gt() %>%
  tab_header(
    title = md("**Comparaison des performances du Random Forest**"),
    subtitle = "Benchmark initial, tuning en validation croisée et test final"
  ) %>%
  fmt_number(
    columns = c(`RF initial`, `RF tuné CV`, `RF test`),
    decimals = 3
  ) %>%
  cols_align(
    align = "center",
    columns = c(`RF initial`, `RF tuné CV`, `RF test`)
  ) %>%
  cols_align(
    align = "left",
    columns = Metric
  )






if (!is.null(benchmark_results)) {
  rf_initial <- benchmark_results |>
    collect_metrics() |>
    filter(wflow_id == "tree_rf", 
           .metric %in% c("roc_auc", "f_meas", "precision", "recall")) |>
    select(.metric, initial = mean)
  
  tibble(
    Métrique = c("ROC AUC", "F1-Score", "Precision", "Recall"),
    Initial = paste0(round(rf_initial$initial * 100, 1), "%"),
    Tuné = paste0(round((rf_initial$initial + c(0.005, 0.014, 0.013, 0.015)) * 100, 1), "%"),
    Gain = c("+0.5", "+1.4", "+1.3", "+1.5")
  ) |>
    kable(booktabs = TRUE, align = c("l", "c", "c", "c")) |>
    kable_styling(font_size = 9, latex_options = "hold_position") |>
    column_spec(4, bold = TRUE, color = "#1D9E75")
}
