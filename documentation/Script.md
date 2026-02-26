# Fonctionnement des scripts : 

## Structure du dossier 

```
script/
├── 00_presentation_des_donnes.R
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