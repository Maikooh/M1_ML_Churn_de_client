# ══════════════════════════════════════════════════════════════════════════════
# 07_tuning.R
# ══════════════════════════════════════════════════════════════════════════════
#
# Ce script effectue le tuning des hyperparamètres pour tous les modèles.
# Stratégie : Latin Hypercube Sampling (exploration efficace de l'espace) +
# tune_race_anova() (élimination précoce des configurations peu prometteuses).
#
# Caractéristiques du dataset prises en compte :
#   - n = 3150 observations (2520 train après split 80/20)
#   - p = 13 prédicteurs (davantage après one-hot pour XGBoost)
#   - Déséquilibre : ~16 % Churn = Yes
#   - Variables mixtes : continues, binaires, ordinales
#
# Modèles tunés :
#   - Random Forest  : mtry, min_n
#   - XGBoost        : trees, learn_rate, tree_depth, mtry, min_n, loss_reduction
#   - KNN            : neighbors
#   - SVM linéaire   : cost
#   - SVM RBF        : cost, rbf_sigma
#   - Decision Tree  : cost_complexity, tree_depth, min_n
#
# Modèles NON tunés (pas d'hyperparamètres ou tuning non pertinent) :
#   - Logit          : régression logistique sans régularisation (baseline)
#   - Bagging        : mtry fixé à p (définition du bagging)
#   - LDA / QDA      : pas d'hyperparamètres avec MASS
#
# Prérequis : exécuter les scripts 00 à 04 ou sourcer 05_benchmark_initial.R
#
# Objets exportés :
#   tuning_results      — workflow_set avec résultats de tuning
#   best_params         — tibble des meilleurs hyperparamètres par modèle
#   plot_tuning_results — classement post-tuning par ROC AUC

library(tidymodels)
library(finetune) # tune_race_anova()
library(future)
library(doFuture)
library(ranger)
library(xgboost)
library(kknn)
library(kernlab)
library(discrim)

# Vérification silencieuse de lme4 (requis par tune_race_anova)
if (!requireNamespace("lme4", quietly = TRUE)) {
  stop("Le package 'lme4' est requis pour tune_race_anova(). Installer avec install.packages('lme4').")
}


# ── 0. Sourcing des scripts précédents ───────────────────────────────────────

exec_precedent <- TRUE

if (exec_precedent) {
  source("script/00_presentation_des_donnees.R")
  source("script/01_analyse_exploratoire.R")
  source("script/02_echantillon_et_recipe.R")
  source("script/03_model_spec.R")
  source("script/04_workflow.R")
}

options(yardstick.event_first = FALSE)
churn_metrics <- metric_set(roc_auc, f_meas, precision, recall, accuracy)


# ══════════════════════════════════════════════════════════════════════════════
# 1. SPÉCIFICATIONS AVEC HYPERPARAMÈTRES À TUNER
# ══════════════════════════════════════════════════════════════════════════════
#
# Justification des ranges par modèle :
#
# ┌─────────────────┬────────────────────────────────────────────────────────────┐
# │ Modèle          │ Justification des hyperparamètres                          │
# ├─────────────────┼────────────────────────────────────────────────────────────┤
# │ Random Forest   │ mtry ∈ [2, 12] : de très restrictif à presque bagging      │
# │                 │ min_n ∈ [2, 30] : nœuds fins à grossiers                    │
# ├─────────────────┼────────────────────────────────────────────────────────────┤
# │ XGBoost         │ trees ∈ [100, 1000] : avec early stopping                  │
# │                 │ learn_rate ∈ [0.01, 0.3] : conservateur à agressif         │
# │                 │ tree_depth ∈ [3, 10] : interactions simples à complexes    │
# │                 │ mtry ∈ [5, 18] : ~30% à 100% des colonnes (après one-hot)  │
# │                 │ min_n ∈ [2, 20] : régularisation structurelle              │
# │                 │ loss_reduction ∈ [0, 5] : gamma pour pruning               │
# ├─────────────────┼────────────────────────────────────────────────────────────┤
# │ KNN             │ neighbors ∈ [3, 50] : de local à plus lissé                │
# │                 │ sqrt(2520) ≈ 50, on explore jusqu'à cette borne            │
# ├─────────────────┼────────────────────────────────────────────────────────────┤
# │ SVM linéaire    │ cost ∈ [0.01, 100] : de très régularisé à peu régularisé   │
# ├─────────────────┼────────────────────────────────────────────────────────────┤
# │ SVM RBF         │ cost ∈ [0.1, 100] : marge souple à dure                    │
# │                 │ rbf_sigma ∈ [0.001, 1] : noyau large à étroit              │
# ├─────────────────┼────────────────────────────────────────────────────────────┤
# │ Decision Tree   │ cost_complexity ∈ [1e-5, 0.1] : de non pruné à très pruné  │
# │                 │ tree_depth ∈ [3, 15] : arbres simples à profonds           │
# │                 │ min_n ∈ [2, 30] : feuilles fines à grossières              │
# └─────────────────┴────────────────────────────────────────────────────────────┘


# 1.1 Random Forest ───────────────────────────────────────────────────────────

rf_tune_spec <- rand_forest(
  trees = 500,
  mtry  = tune(),
  min_n = tune()
) |>
  set_engine("ranger", importance = "permutation") |>
  set_mode("classification")


# 1.2 XGBoost ─────────────────────────────────────────────────────────────────

xgb_tune_spec <- boost_tree(
  trees          = tune(),
  learn_rate     = tune(),
  tree_depth     = tune(),
  mtry           = tune(),
  min_n          = tune(),
  loss_reduction = tune(),
  stop_iter      = 20
) |>
  set_engine("xgboost") |>
  set_mode("classification")


# 1.3 KNN ─────────────────────────────────────────────────────────────────────

knn_tune_spec <- nearest_neighbor(
  neighbors = tune()
) |>
  set_engine("kknn") |>
  set_mode("classification")


# 1.4 SVM linéaire ────────────────────────────────────────────────────────────

svm_lin_tune_spec <- svm_linear(
  cost = tune()
) |>
  set_engine("kernlab") |>
  set_mode("classification")


# 1.5 SVM RBF ─────────────────────────────────────────────────────────────────

svm_rad_tune_spec <- svm_rbf(
  cost      = tune(),
  rbf_sigma = tune()
) |>
  set_engine("kernlab") |>
  set_mode("classification")


# 1.6 Decision Tree ───────────────────────────────────────────────────────────

tree_tune_spec <- decision_tree(
  cost_complexity = tune(),
  tree_depth      = tune(),
  min_n           = tune()
) |>
  set_engine("rpart") |>
  set_mode("classification")


# ══════════════════════════════════════════════════════════════════════════════
# 2. CONSTRUCTION DES WORKFLOW SETS (AVEC ET SANS TUNING)
# ══════════════════════════════════════════════════════════════════════════════

# 2.1 Workflows AVEC hyperparamètres à tuner
tuning_workflows <- workflow_set(
  preproc = list(
    tree = recipe_tree,
    xgb  = recipe_xgb,
    dist = recipe_distance
  ),
  models = list(
    rf      = rf_tune_spec,
    xgb     = xgb_tune_spec,
    knn     = knn_tune_spec,
    svm_lin = svm_lin_tune_spec,
    svm_rad = svm_rad_tune_spec,
    dt      = tree_tune_spec
  ),
  cross = TRUE
) |>
  filter(wflow_id %in% c(
    "tree_rf", "tree_dt",
    "xgb_xgb",
    "dist_knn", "dist_svm_lin", "dist_svm_rad"
  ))


# 2.2 Workflows SANS tuning (hyperparamètres fixes ou inexistants)
#
# Note : la régression logistique est incluse ici car le tuning de la
# régularisation via glmnet pose des problèmes de compatibilité. Elle reste
# un baseline pertinent sans régularisation (penalty = 0).

fixed_workflows <- workflow_set(
  preproc = list(
    tree    = recipe_tree,
    dist    = recipe_distance,
    discrim = recipe_lda_qda
  ),
  models = list(
    bag   = bagging_spec,
    logit = logit_spec,
    lda   = lda_spec,
    qda   = qda_spec
  ),
  cross = TRUE
) |>
  filter(wflow_id %in% c("tree_bag", "dist_logit", "discrim_lda", "discrim_qda"))


# ══════════════════════════════════════════════════════════════════════════════
# 3. GRILLES D'HYPERPARAMÈTRES (Latin Hypercube)
# ══════════════════════════════════════════════════════════════════════════════
#
# Latin Hypercube Sampling : exploration efficace de l'espace avec moins de
# points qu'une grille régulière, tout en couvrant uniformément chaque dimension.
# 30 points par modèle = bon compromis exploration / temps de calcul.

set.seed(2026)

# 3.1 Random Forest
grid_rf <- grid_latin_hypercube(
  mtry(range = c(2L, 12L)),
  min_n(range = c(2L, 30L)),
  size = 30
)

# 3.2 XGBoost
# Note : mtry = nombre de colonnes à échantillonner par arbre.
# Après one-hot encoding des 5 facteurs binaires : ~18 colonnes.
# Range [5, 18] pour explorer de 30% à 100% des features.
grid_xgb <- grid_latin_hypercube(
  trees(range = c(100L, 1000L)),
  learn_rate(range = c(-2, -0.5)), # log10 scale : 0.01 à 0.3
  tree_depth(range = c(3L, 10L)),
  mtry(range = c(5L, 18L)), # nombre de colonnes (après one-hot)
  min_n(range = c(2L, 20L)),
  loss_reduction(range = c(0, 5)), # gamma
  size = 30
)

# 3.3 KNN
grid_knn <- grid_latin_hypercube(
  neighbors(range = c(3L, 50L)),
  size = 20
)

# 3.4 SVM linéaire
grid_svm_lin <- grid_latin_hypercube(
  cost(range = c(-2, 2)), # log10 scale : 0.01 à 100
  size = 20
)

# 3.5 SVM RBF
grid_svm_rad <- grid_latin_hypercube(
  cost(range = c(-1, 2)), # log10 scale : 0.1 à 100
  rbf_sigma(range = c(-3, 0)), # log10 scale : 0.001 à 1
  size = 30
)

# 3.6 Decision Tree
grid_tree <- grid_latin_hypercube(
  cost_complexity(range = c(-5, -1)), # log10 scale : 1e-5 à 0.1
  tree_depth(range = c(3L, 15L)),
  min_n(range = c(2L, 30L)),
  size = 30
)


# ══════════════════════════════════════════════════════════════════════════════
# 4. ASSOCIATION DES GRILLES AUX WORKFLOWS
# ══════════════════════════════════════════════════════════════════════════════

tuning_workflows <- tuning_workflows |>
  option_add(grid = grid_rf, id = "tree_rf") |>
  option_add(grid = grid_tree, id = "tree_dt") |>
  option_add(grid = grid_xgb, id = "xgb_xgb") |>
  option_add(grid = grid_knn, id = "dist_knn") |>
  option_add(grid = grid_svm_lin, id = "dist_svm_lin") |>
  option_add(grid = grid_svm_rad, id = "dist_svm_rad")


# ══════════════════════════════════════════════════════════════════════════════
# 5. EXÉCUTION DU TUNING
# ══════════════════════════════════════════════════════════════════════════════
#
# Stratégie en deux temps :
#   1. tune_race_anova() pour les modèles avec hyperparamètres
#   2. fit_resamples() pour les modèles à hyperparamètres fixes (bag, logit, LDA, QDA)
#
# tune_race_anova() : élimine précocement les configurations peu prometteuses
# via un test ANOVA après chaque fold (burn_in = 3 folds avant élimination).

rds_path <- "data/tuning_results_churn.rds"

if (file.exists(rds_path)) {
  message("Chargement des résultats de tuning existants depuis ", rds_path)
  tuning_results <- readRDS(rds_path)
} else {
  plan(multisession, workers = parallel::detectCores() - 1)
  registerDoFuture()
  on.exit(plan(sequential), add = TRUE)

  set.seed(2026)

  race_ctrl <- control_race(
    save_pred     = TRUE,
    verbose       = TRUE,
    verbose_elim  = TRUE,
    burn_in       = 3,
    save_workflow = TRUE
  )

  resamples_ctrl <- control_resamples(
    save_pred = TRUE,
    verbose   = TRUE
  )

  # ── 5.1 Tuning des modèles avec hyperparamètres ─────────────────────────────
  message("\n", strrep("═", 60))
  message("PHASE 1 : Tuning des modèles avec hyperparamètres")
  message(strrep("═", 60), "\n")

  system.time(
    tuned_results <- tuning_workflows |>
      workflow_map(
        fn        = "tune_race_anova",
        resamples = churn_folds,
        metrics   = churn_metrics,
        control   = race_ctrl,
        seed      = 2026,
        verbose   = TRUE
      )
  )

  # ── 5.2 Évaluation des modèles sans tuning ──────────────────────────────────
  message("\n", strrep("═", 60))
  message("PHASE 2 : Évaluation des modèles sans tuning (Bagging, Logit, LDA, QDA)")
  message(strrep("═", 60), "\n")

  system.time(
    fixed_results <- fixed_workflows |>
      workflow_map(
        fn        = "fit_resamples",
        resamples = churn_folds,
        metrics   = churn_metrics,
        control   = resamples_ctrl,
        seed      = 2026,
        verbose   = TRUE
      )
  )

  # ── 5.3 Fusion des résultats ────────────────────────────────────────────────
  tuning_results <- bind_rows(tuned_results, fixed_results)

  saveRDS(tuning_results, rds_path)
  message("\nRésultats sauvegardés dans ", rds_path)
}


# ══════════════════════════════════════════════════════════════════════════════
# 6. EXTRACTION DES MEILLEURS HYPERPARAMÈTRES
# ══════════════════════════════════════════════════════════════════════════════

best_params <- tuning_results |>
  rank_results(rank_metric = "roc_auc", select_best = TRUE) |>
  filter(.metric == "roc_auc") |>
  select(wflow_id, .config, mean, std_err) |>
  rename(
    Modèle   = wflow_id,
    Config   = .config,
    ROC_AUC  = mean,
    SE       = std_err
  ) |>
  arrange(desc(ROC_AUC))

# Affichage des meilleurs paramètres détaillés par modèle
extract_best_params <- function(wflow_id) {
  result <- tuning_results |>
    extract_workflow_set_result(id = wflow_id)

  if (inherits(result, "tune_results")) {
    select_best(result, metric = "roc_auc")
  } else {
    tibble(note = "Pas de tuning (hyperparamètres fixes)")
  }
}

best_params_detail <- tuning_results |>
  pull(wflow_id) |>
  set_names() |>
  map(extract_best_params)


# ══════════════════════════════════════════════════════════════════════════════
# 7. VISUALISATION DES RÉSULTATS
# ══════════════════════════════════════════════════════════════════════════════

# Palette étendue pour tous les modèles
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

# Classement post-tuning par ROC AUC
plot_tuning_results <- tuning_results |>
  rank_results(rank_metric = "roc_auc", select_best = TRUE) |>
  filter(.metric == "roc_auc") |>
  mutate(wflow_id = fct_reorder(wflow_id, mean)) |>
  ggplot(aes(x = mean, y = wflow_id, colour = wflow_id)) +
  geom_point(size = 3, show.legend = FALSE) +
  geom_errorbar(
    aes(xmin = mean - 1.96 * std_err, xmax = mean + 1.96 * std_err),
    width = 0.25, alpha = 0.6, show.legend = FALSE,
    orientation = "y"
  ) +
  scale_colour_manual(values = palette_modeles) +
  scale_x_continuous(labels = scales::label_percent(), limits = c(NA, 1)) +
  labs(
    title    = "Classement des modèles après tuning",
    subtitle = "Meilleure configuration par modèle — ROC AUC (moyenne ± 1,96 × SE)",
    x        = "ROC AUC",
    y        = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold"))


# ══════════════════════════════════════════════════════════════════════════════
# 8. TABLEAU RÉCAPITULATIF DES MEILLEURS HYPERPARAMÈTRES
# ══════════════════════════════════════════════════════════════════════════════

# Affichage console des meilleurs paramètres
message("\n", strrep("═", 60))
message("MEILLEURS HYPERPARAMÈTRES PAR MODÈLE")
message(strrep("═", 60), "\n")

for (model_name in names(best_params_detail)) {
  message("▸ ", model_name)
  print(best_params_detail[[model_name]])
  message("")
}


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
  "tuning_results",
  "best_params", "best_params_detail",
  "plot_tuning_results",
  "palette_modeles",
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
