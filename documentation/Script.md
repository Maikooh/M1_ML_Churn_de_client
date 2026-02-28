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