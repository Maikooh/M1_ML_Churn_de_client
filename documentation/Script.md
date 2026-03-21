# Fonctionnement des scripts : 

## Structure du dossier 

```
script/
├── 00_presentation_des_donnes.R
├── 01_analyse_exploratoire.R
└── ...
```

### `00_presentation_des_donnes.R` : 

Ce script charge et prépare une présentation structurée des données de churn clients. Il effectue les opérations suivantes :

1. **Chargement des données** : Importe le fichier CSV contenant les informations des clients
2. **Formatage des noms** : Nettoie et formate les noms de colonnes (suppression des points, conversion en casse titre)
3. **Création d'un dictionnaire** : Construit un tableau récapitulatif avec :
   - Les noms des variables formatés
   - Les types de données
   - Une description détaillée de chaque variable 
4. **Génération d'un tableau** : Crée un tableau stylisé avec `kable` et `kableExtra` pour une meilleure présentation

Le résultat (`tableau_presentation_donnees`) peut être intégré dans des rapports RMarkdown pour documenter la structure du dataset.

### `01_analyse_exploratoire.R` : 

Ce script réalise une analyse exploratoire des données de churn clients. Il effectue les opérations suivantes :

1. **Analyse des variables numériques** : Calcule et présente les statistiques descriptives complètes :
   - Mesures de tendance centrale (minimum, quartiles, médiane, moyenne, maximum)
   - Mesure de dispersion (écart-type)
   - Taux de valeurs manquantes (NA %)
   
2. **Analyse des variables catégorielles** : Génère un tableau de fréquences détaillé avec :
   - Distribution des effectifs par modalité
   - Proportions en pourcentage
   - Taux de valeurs manquantes
   - Regroupement par variable avec lignes fusionnées pour une meilleure lisibilité

3. **Présentation des résultats** : Crée deux tableaux stylisés (`tableau_summary` et `tableau_summary_cat`) avec `kable` et `kableExtra` pour intégration dans le rapport

**Prérequis** : L'objet `data` doit être chargé en mémoire avant l'exécution de ce script.

### `02_echantillon_et_recipe.R` :

Ce script prépare les données pour la modélisation supervisée en séparant les jeux d'apprentissage et de test, puis en définissant des recettes de prétraitement adaptées à chaque famille de modèles. Il effectue les opérations suivantes :

1. **Découpage train/test stratifié** : Crée une séparation 80/20 avec `initial_split(..., strata = Churn)` pour conserver la distribution de la variable cible
2. **Validation croisée** : Génère des folds de validation croisée stratifiés (`vfold_cv`, 10 folds)
3. **Recette pour arbres** (`recipe_tree`) :
   - Imputation des numériques par la médiane
   - Imputation des catégorielles par la modalité majoritaire
   - Encodage dummy des catégorielles (utile pour SMOTE)
   - Sur-échantillonnage de la classe minoritaire via `step_smote(Churn)`
4. **Recette pour boosting/ensemble** (`recipe_xgb`) :
   - Imputation numérique/catégorielle
   - Encodage one-hot (`one_hot = TRUE`) requis pour XGBoost
   - Suppression des variables à variance nulle
   - Application de SMOTE
5. **Recette pour modèles de distance** (`recipe_distance`) :
   - Imputation numérique/catégorielle
   - Encodage dummy
   - Suppression des variables à variance nulle
   - Normalisation des variables numériques
   - Application de SMOTE
6. **Recette pour modèles discriminants** (`recipe_discrim`) :
   - Imputation numérique/catégorielle
   - Encodage dummy
   - Suppression des variables à variance nulle
   - Filtrage des corrélations fortes (`threshold = 0.9`)
   - Application de SMOTE
7. **Bloc de vérification optionnel** : Active un contrôle qualité (`affichage_des_verifs`) pour inspecter les transformations produites par chaque recette

**Prérequis** : L'objet `data` et la variable cible `Churn` doivent être disponibles en mémoire.

**Résultats principaux** : `train_data`, `test_data`, `churn_folds`, `recipe_tree`, `recipe_xgb`, `recipe_distance`, `recipe_discrim`.

### `03_model_spec.R` :

Ce script définit les spécifications des modèles à comparer lors du benchmark initial, organisés par familles. Il effectue les opérations suivantes :

1. **Chargement des bibliothèques de modélisation** : `tidymodels`, `discrim`, `kknn`, `ranger`, `xgboost`, `kernlab`
2. **Définition des modèles arbres/ensemble** :
   - `rf_spec` : Random Forest (`ranger`, 1000 arbres)
   - `xgb_spec` : Boosting XGBoost (`xgboost`, 1000 arbres)
   - `bagging_spec` : Bagging via Random Forest avec `mtry = .preds()`
   - `tree_spec` : Arbre de décision (`rpart`)
3. **Définition des modèles géométriques de distance** :
   - `knn_spec` : KNN (`kknn`, `neighbors = 10`)
   - `svm_rad_spec` : SVM noyau radial (`kernlab`)
   - `svm_lin_spec` : SVM linéaire (`kernlab`)
4. **Définition des modèles discriminants** :
   - `lda_spec` : Analyse discriminante linéaire (`MASS`)
   - `qda_spec` : Analyse discriminante quadratique (`MASS`)
5. **Mode commun** : Toutes les spécifications sont en mode `classification`

**Prérequis** : Les packages listés doivent être installés.

**Résultats principaux** : Objets de spécification `*_spec` utilisés dans le workflow set.

### `04_workflow.R` :

Ce script assemble les recettes de prétraitement et les spécifications de modèles dans un `workflow_set` pour préparer le benchmark. Il effectue les opérations suivantes :

1. **Création du workflow set global** :
   - Associe les prétraitements `tree`, `xgb`, `dist`, `discrim`
   - Associe les modèles `rf`, `xgb`, `bag`, `dt`, `knn`, `svm_rad`, `svm_lin`, `lda`, `qda`
   - Active la combinaison croisée via `cross = TRUE`
2. **Filtrage des combinaisons pertinentes** : Conserve uniquement les workflows réellement souhaités :
   - Arbres : `tree_rf`, `tree_bag`, `tree_dt`
   - Boosting : `xgb_xgb`
   - Distance : `dist_knn`, `dist_svm_rad`, `dist_svm_lin`
   - Discriminants : `discrim_lda`, `discrim_qda`
3. **Bloc d'affichage optionnel** : Permet de lister les identifiants de workflows via `affichage_workflow`

**Prérequis** : Les objets recettes (`recipe_*`) et modèles (`*_spec`) doivent être déjà créés.

**Résultat principal** : Objet `all_workflows` prêt pour l'étape de resampling/benchmark.

### `05_benchmark_initial.R` :

Ce script exécute le benchmark initial des workflows en validation croisée et enregistre les résultats. Il effectue les opérations suivantes :

1. **Configuration du calcul parallèle** :
   - Initialise `future`/`doFuture`
   - Utilise un plan `multisession` avec `detectCores() - 1` workers
2. **Définition des métriques d'évaluation** :
   - `roc_auc`
   - `f_meas`
   - `accuracy`
   - `precision`
   - `recall`
3. **Lancement du benchmark** :
   - Applique `workflow_map(fn = "fit_resamples")` sur `all_workflows`
   - Utilise les folds `churn_folds` et les métriques définies
   - Mesure le temps d'exécution avec `system.time`
4. **Retour au mode séquentiel** : Réinitialise le plan avec `plan(sequential)`
5. **Sauvegarde des résultats** : Enregistre `benchmark_results` dans `data/benchmark_results_churn.rds`
6. **Analyse rapide des performances** :
   - Classe les meilleurs modèles avec `rank_results(..., rank_metric = "roc_auc")`
   - Visualise les performances avec `autoplot(..., metric = "roc_auc")`

**Prérequis** : Les objets `all_workflows` et `churn_folds` doivent être disponibles.

**Résultat principal** : Objet `benchmark_results` sauvegardé et prêt pour l'interprétation/comparaison des modèles.