# Churn Clients Telecom 

Projet de classification supervisée pour la prédiction du churn (départ) de clients dans une entreprise de télécommunications.

## Données

Les données proviennent du dataset **Iranian Churn Dataset** disponible sur :
https://archive.ics.uci.edu/dataset/563/iranian+churn+dataset

Fichier : `data/Customer Churn.csv`

## Structure du projet

```
├── script/              # Scripts R pour l'analyse et modélisation
├── documentation/       # Documentation sur l'utilisation de l'IA
├── data/               # Données d'entrée
└── Churn_de_clients_d_une_entreprise_de_telecom.rmd  # Notebook principal
```

### Dossiers

- **`script/`** : Ensemble des scripts R réutilisables pour le traitement des données, l'EDA et la construction des modèles
- **`documentation/`** : Documentation relative à l'utilisation et l'application de l'IA dans le projet
- **`data/`** : Fichiers de données brutes et traitées

## Versioning

Ce projet utilise **Git/GitHub** pour le suivi des versions et la collaboration.

## Note

Le fichier `.Rmd` contient uniquement des appels aux scripts situés dans le dossier `script/`.