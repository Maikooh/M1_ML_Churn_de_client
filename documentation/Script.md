---

### `00_presentation_des_donnees.R`

Charge le CSV, encode les variables catégorielles en facteurs, et construit un dictionnaire des variables. Exporte `data` et `tableau_presentation_donnees`.

---

### `01_analyse_exploratoire.R`

Produit les statistiques descriptives et les visualisations exploratoires. Exporte `tableau_summary_num`, `tableau_summary_cat`, `plot_desequilibre`, `plot_dist_num`, `plot_boxplot_churn`, `plot_correlation`, `plot_cat_churn`.

**Prérequis** : `data`

---

### `02_echantillon_et_recipe.R`

Partitionne les données (80/20 stratifié), crée les folds de validation croisée (10 folds stratifiés), et définit quatre recettes de prétraitement adaptées à chaque famille de modèles :

- `recipe_tree` : imputation + SMOTENC (pas de normalisation ni de dummies)
- `recipe_xgb` : imputation + encodage one-hot + step_zv + SMOTE
- `recipe_distance` : imputation + dummies + step_zv + normalisation + SMOTE
- `recipe_lda_qda` : imputation + dummies + step_zv + normalisation + ACP (95 %) + SMOTE

SMOTE est toujours appliqué en dernière étape pour éviter toute fuite de données vers les folds de validation.

**Prérequis** : `data`

**Exporte** : `churn_split`, `train_data`, `test_data`, `churn_folds`, `recipe_tree`, `recipe_xgb`, `recipe_distance`, `recipe_lda_qda`

---

### `03_model_spec.R`

Définit les spécifications des dix modèles sans hyperparamètres tunés (valeurs par défaut raisonnées) :

- Baseline : `logit_spec`
- Arbres/ensemble : `tree_spec`, `bagging_spec`, `rf_spec`, `xgb_spec`
- Distance : `knn_spec`, `svm_lin_spec`, `svm_rad_spec`
- Discriminants : `lda_spec`, `qda_spec`

---

### `04_workflow.R`

Assemble recettes et modèles dans un `workflow_set` via `cross = TRUE`, puis filtre les dix combinaisons méthodologiquement valides :

| Recipe | Modèles |
|---|---|
| `recipe_tree` | `tree_dt`, `tree_bag`, `tree_rf` |
| `recipe_xgb` | `xgb_xgb` |
| `recipe_distance` | `dist_logit`, `dist_knn`, `dist_svm_lin`, `dist_svm_rad` |
| `recipe_lda_qda` | `discrim_lda`, `discrim_qda` |

**Exporte** : `all_workflows`

---

### `05_benchmark_initial.R`

Évalue les dix workflows par validation croisée (`fit_resamples`) en parallèle (`multisession`). Persiste les résultats dans `data/benchmark_results_churn.rds` pour éviter les recalculs.

**Métriques** : `roc_auc`, `f_meas`, `precision`, `recall`, `accuracy`

**Exporte** : `benchmark_results`, `plot_benchmark_roc`, `plot_benchmark_all`

---

### `06_benchmark_visualisation.R`

Produit les visualisations et tableaux de comparaison du benchmark initial.

**Exporte** : `tableau_metriques`, `plot_benchmark_roc`, `plot_roc_curves`, `plot_metrics_heatmap`, `plot_conf_matrices`

**Prérequis** : `benchmark_results` (chargé depuis le `.rds` si absent)

---

### `07_xgb_tuning.R`

Optimise les hyperparamètres XGBoost en deux phases via Latin Hypercube + `tune_race_anova` :

- **Phase 1** — exploration large (50 combinaisons, espaces larges), résultats persistés dans `data/xgb_tune_p1.rds`
- **Phase 2** — zoom local autour des meilleurs paramètres (40 combinaisons, grille resserrée), résultats persistés dans `data/xgb_tune_p2.rds`

**Exporte** : `xgb_tune_results`, `xgb_zoom_results`, `xgb_best_params`, `xgb_final_wflow`, `plot_xgb_tuning`, `plot_xgb_zoom`, `plot_xgb_importance`

---

### `08_evaluation_finale.R`

Évalue le workflow XGBoost finalisé sur le jeu de test via `last_fit()`. Produit les résultats définitifs et les visualisations associées.

**Exporte** : `xgb_last_fit`, `test_metrics`, `test_predictions`, `cv_vs_test`, `summary_table`, `plot_confusion_matrix`, `plot_roc_curve`, `plot_prob_distribution`, `plot_threshold_analysis`

**Prérequis** : `xgb_final_wflow` (sourcé depuis `07_xgb_tuning.R` si absent)