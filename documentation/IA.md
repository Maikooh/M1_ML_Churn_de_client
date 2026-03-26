# Documentation de l'usage de l'ia

## Structure initiale du readme  

Prompt donné à Github copilot via vscode pour reformater le `README.md` initial du projet: 

```
Reformate mon readme de manière propre, concise et sans usage d'emoji en incluant:

- Titre et description du projet basé sur mon asbtract dans le fichier `Churn_de_clients_d_une_entreprise_de_tele_com.pdf`
- Lien vers la source des données (Iranian Churn Dataset) : https://archive.ics.uci.edu/dataset/563/iranian+churn+dataset
- Structure claire des trois dossiers (script, documentation, data)
- Mention de Git/GitHub pour le versioning
- Note sur l'architecture du fichier .Rmd
```

## Feuille de route

Prompt donné à Copilot via vscode pour la génération du fichier `TodoList.md`:

```
Génère une feuille de route complète en Markdown pour un projet de Machine Learning, rédigée en français, avec une structure académique.

La structure doit inclure :

- Un Abstract avec résumé court (problème, données, méthodes, résultats, conclusion)

- Une Introduction avec contexte, problématique et question de recherche

- Une section Revue de littérature (optionnelle)

- Une Description des données (source, variables, déséquilibre éventuel)

- Une section Méthodologie détaillant la préparation des données (nettoyage, encodage factor, normalisation si nécessaire, gestion du déséquilibre), la séparation train/test avec stratification, et les métriques d’évaluation (accuracy, précision, recall, F1, ROC-AUC)

- Une section Modèles incluant un modèle de référence puis au moins deux modèles comparés

- Une section Résultats avec tableau comparatif des métriques

- Une section Interprétation du modèle (importance des variables + interprétation métier)

- Une Discussion (forces, limites, hypothèses)

- Une Conclusion

- Une section Perspectives d’amélioration (nouveaux modèles, enrichissement des données, monitoring)

Le document doit être structuré avec des titres hiérarchiques (H1, H2, H3), des listes à puces, des séparateurs visuels ---, et être prêt à copier-coller dans un README.
```

# Documentation des script

Prompt donné à copilot :
```
En suivant la structure de mon fichier Script.md, ajoute le fonctionnement de mes script 02 à 05.
```


# Question de méthode / renseignement

Diverse question sur ChatGPT

```
- J'utilise tidymodels pour setup différents modèles de classification. Explique moi la différence entre un workflow général pour plusieurs modeles et et un workflow propre à chaque modèle, fait en un comparatif en particulier au niveau méthodologique

- Explique moi comment fonctionne SMOTE dans tidymodels

- Comment utiliser le package R "worfklowsets" dont voici la documentation : https://workflowsets.tidymodels.org/

- ...

```


# Refactorisation et "controle qualité"

Utilisation de Claude : 

`Claude.md` :
```
Tu es un expert en data science et machine learning spécialisé en R, utilisant RStudio et l’écosystème tidymodels.

Ton rôle est de m’accompagner dans la réalisation d’études de machine learning complètes et professionnelles.

Quand je te pose une question ou te donne un projet :

* Tu proposes une démarche structurée : exploration des données (EDA), preprocessing, feature engineering, modélisation, évaluation.
* Tu utilises exclusivement R avec les packages du tidyverse et tidymodels (recipes, parsnip, workflows, tune, yardstick).
* Tu écris du code propre, reproductible et idiomatique R (pipe |> ou %>%).
* Tu privilégies les workflows tidymodels (recipe + model + workflow).
* Tu intègres des bonnes pratiques : cross-validation, tuning d’hyperparamètres, séparation train/test.
* Tu expliques clairement tes choix (modèles, transformations, métriques).
* Tu proposes plusieurs approches avec leurs avantages et limites.
* Tu anticipes les problèmes (overfitting, data leakage, déséquilibre des classes).

Tu réponds de manière structurée, claire et actionnable.

Si le problème est incomplet, pose des questions pour clarifier avant de répondre.

Adapte le niveau d’explication selon ma demande (débutant à expert).

Propose toujours des améliorations ou des pistes auxquelles je n’ai pas pensé.
Priorise toujours les solutions basées sur tidymodels plutôt que base R ou caret.


```

`context.md` :
```
Contexte du projet :
Je travaille sur un dataset de churn client :
https://archive.ics.uci.edu/dataset/563/iranian+churn+dataset

Objectif :
Prédire la variable "Churn" avec des modèles de classification supervisée.

Contraintes techniques :

* Utiliser exclusivement R avec tidymodels
* Utiliser les packages : recipes, parsnip, workflows, tune, yardstick
* Produire du code propre, reproductible et structuré

Méthodologie attendue :
Tu dois toujours structurer tes réponses selon les étapes suivantes :

1. EDA (analyse exploratoire)

   * Analyse des variables
   * Visualisations pertinentes
   * Corrélations
   * Déséquilibre de classes

2. Préprocessing

   * recipe tidymodels
   * gestion des variables catégorielles
   * normalisation / standardisation
   * gestion des valeurs manquantes

3. Modélisation

   * Implémenter : LDA, QDA, SVM (linéaire et radial), KNN, Random Forest, XGBoost
   * Utiliser des workflows
   * Faire de la validation croisée
   * Tuner les hyperparamètres

4. Évaluation

   * Comparer avec accuracy, ROC AUC, F1-score
   * Matrice de confusion
   * Analyse du surapprentissage

5. Interprétation

   * Identifier le meilleur modèle
   * Importance des variables
   * Limites et améliorations possibles

Objectif final :
Produire une analyse rigoureuse pour un rapport académique.

Comportement attendu :

* Toujours expliquer les choix
* Proposer plusieurs approches si pertinent
* Signaler les erreurs ou mauvaises pratiques
* Poser des questions si le problème est incomplet
* Proposer des améliorations pertinentes

Variables disponibles :
Additional variable information :
Anonymous Customer ID 
Call Failures: number of call failures 
Complains: binary (0: No complaint, 1: complaint) 
Subscription Length: total months of subscription
Charge Amount: Ordinal attribute (0: lowest amount, 9: highest amount) 
Seconds of Use: total seconds of calls 
Frequency of use: total number of calls
Frequency of SMS: total number of text messages 
Distinct Called Numbers: total number of distinct phone calls 
Age Group: ordinal attribute (1: younger age, 5: older age) 
Tariff Plan: binary (1: Pay as you go, 2: contractual) 
Status: binary (1: active, 2: non-active) 
Churn: binary (1: churn, 0: non-churn) - variable cible 
Customer Value: valeur calculée du client
```
`Prompt`
```
Au vu des informations que je t’ai fournies précédemment, analyse en détail le travail que j’ai déjà produit.

Réalise une review structurée et argumentée en distinguant clairement :

- Les points réussis : ce qui est pertinent, bien exécuté, cohérent ou efficace, avec une explication du pourquoi.

- Les points à améliorer : ce qui pourrait être optimisé, clarifié ou approfondi

- Les erreurs ou incohérences : ce qui n’est pas correct, imprécis ou mal adapté, avec une justification claire.
Les recommandations : propose des pistes d’amélioration concrètes et prioritaires pour renforcer la qualité globale du travail.

- Inclue également une analyse de la qualité du code en proposant, si nécessaire, des suggestions de refactorisation afin de le rendre plus lisible, mieux structuré, maintenable et correctement documenté.

Appuie-toi uniquement sur les éléments fournis et évite les suppositions. Sois précis, critique mais constructif, et adopte un ton professionnel.
``` 