# Ce script spécialise la recipe des 2 modèles choisies
# random forest et bosting avec l'engine xgboost

# en suivant les recommendations
# de la documentation : https://www.tmwr.org/pre-proc-table.html

args(boost_tree)
args(rand_forest)

# random forest
rf_spec <- rand_forest(trees = 1000) %>%
  set_engine("ranger", importance = "permutation") %>%
  set_mode("classification")

# boosting
xgb_spec <- boost_tree(trees = 1000) %>%
  set_engine("xgboost") %>%
  set_mode("classification")