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