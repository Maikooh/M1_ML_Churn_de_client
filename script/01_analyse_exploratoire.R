# Ce script réalise l'analyse exploratoire complète du jeu de données.
# Prérequis : "data" doit être chargé via 00_presentation_des_donnees.R
#
# Objets exportés (utilisables dans le rapport) :
#   Tableaux  : tableau_summary_num, tableau_summary_cat
#   Graphiques: plot_desequilibre, plot_dist_num, plot_boxplot_churn,
#               plot_correlation, plot_cat_churn

source("script/_utils.R")

# Palette / thème par défaut pour les graphiques
theme_set(
  theme_minimal(base_size = 11) +
    theme(
      plot.title = element_text(face = "bold", size = 12),
      plot.subtitle = element_text(colour = "grey40", size = 10),
      axis.title = element_text(size = 10),
      legend.position = "bottom"
    )
)


# ── 1. Statistiques descriptives – variables numériques ──────────────────────

tableau_summary_num <- data |>
  select(where(is.numeric)) |>
  pivot_longer(everything(), names_to = "Variable") |>
  group_by(Variable) |>
  summarise(
    Min          = min(value, na.rm = TRUE),
    Q1           = quantile(value, 0.25, na.rm = TRUE),
    Médiane      = median(value, na.rm = TRUE),
    Moyenne      = round(mean(value, na.rm = TRUE), 2),
    Q3           = quantile(value, 0.75, na.rm = TRUE),
    Max          = max(value, na.rm = TRUE),
    `Écart-type` = round(sd(value, na.rm = TRUE), 2),
    `NA (%)`     = round(mean(is.na(value)) * 100, 1)
  ) |>
  kable(
    booktabs = TRUE,
    align    = c("l", rep("r", 8))
  ) |>
  kable_styling(
    latex_options = c("striped", "hold_position", "scale_down"),
    font_size     = 9
  )


# ── 2. Statistiques descriptives – variables catégorielles ──────────────────
#
# FIX : l'ancien code convertissait en character via as.character() AVANT de
# grouper, ce qui rendait impossible tout comptage de NA (ils
# devenaient la chaîne "NA"). On travaille désormais directement sur les
# facteurs, on compte les NA séparément, puis on les ajoute au tableau.

tableau_summary_cat <- data |>
  select(where(is.factor)) |>
  pivot_longer(everything(),
    names_to = "Variable", values_to = "Modalite",
    values_transform = as.character
  ) |>
  group_by(Variable) |>
  mutate(`NA (%)` = round(mean(is.na(Modalite)) * 100, 1)) |>
  filter(!is.na(Modalite)) |>
  group_by(Variable, Modalite, `NA (%)`) |>
  summarise(Effectif = n(), .groups = "drop") |>
  group_by(Variable) |>
  mutate(`%` = round(Effectif / sum(Effectif) * 100, 1)) |>
  ungroup() |>
  arrange(Variable, desc(Effectif)) |>
  rename(`Modalité` = Modalite) |>
  kable(
    booktabs = TRUE,
    align    = c("l", "l", "r", "r", "r")
  ) |>
  kable_styling(
    latex_options = c("striped", "hold_position"),
    font_size     = 9
  ) |>
  collapse_rows(columns = c(1, 4), latex_hline = "major", valign = "middle")


# ── 3. Déséquilibre de la variable cible ─────────────────────────────────────
#
# Ce graphique justifie l'usage de SMOTE dans le preprocessing.

prop_churn <- data |>
  count(Churn) |>
  mutate(pct = round(n / sum(n) * 100, 1))

plot_desequilibre <- ggplot(prop_churn, aes(x = Churn, y = n, fill = Churn)) +
  geom_col(width = 0.6, show.legend = FALSE) +
  # Chiffres à l'intérieur
  geom_text(
    aes(label = paste0(pct, "%")),
    vjust = 2, size = 5, fontface = "bold", color = "white"
  ) +
  geom_text(
    aes(label = paste0(n)),
    vjust = 5, size = 3, color = "white"
  ) +
  # Renommage des catégories ici
  scale_fill_manual(
    values = couleurs_churn,
    labels = c("Yes" = "Churner", "No" = "Non Churner")
  ) +
  scale_x_discrete(labels = c("Yes" = "Churner", "No" = "Non Churner")) +
  labs(x = NULL, y = NULL) +
  theme_void() +
  theme(
    axis.text.x = element_text(face = "bold", size = 12, vjust = 3)
  )


# ── 4. Distributions des variables numériques par classe Churn ───────────────
#
# Les densités superposées permettent de voir quelles variables séparent
# bien les deux classes, et donc leur pouvoir discriminant potentiel.

plot_dist_num <- data |>
  select(where(is.numeric), Churn) |>
  pivot_longer(-Churn, names_to = "Variable") |>
  ggplot(aes(x = value, fill = Churn, colour = Churn)) +
  geom_density(alpha = 0.35, linewidth = 0.5) +
  facet_wrap(~Variable, scales = "free", ncol = 3) +
  scale_fill_manual(
    values = couleurs_churn,
    labels = c("No" = "Non Churner", "Yes" = "Churner")
  ) +
  scale_colour_manual(
    values = couleurs_churn,
    labels = c("No" = "Non Churner", "Yes" = "Churner")
  ) +
  labs(
    x        = NULL,
    y        = NULL,
    fill     = NULL, # Supprime le titre du remplissage
    colour   = NULL # Supprime le titre de la bordure
  )


# ── 5. Boxplots – variables numériques par classe Churn ──────────────────────
#
# Complète les densités en rendant visibles la médiane et les outliers.

plot_boxplot_churn <- data |>
  # 1. On retire Age ET Subscription Length pour tomber à 6 graphiques (2x3)
  select(where(is.numeric), Churn, -Age, -"Subscription  Length") |>
  pivot_longer(-Churn, names_to = "Variable") |>
  ggplot(aes(x = Churn, y = value, fill = Churn)) +
  geom_boxplot(outlier.size = 0.5, outlier.alpha = 0.4, linewidth = 0.4) +
  facet_wrap(~Variable, scales = "free_y", ncol = 3) +
  scale_fill_manual(
    values = couleurs_churn,
    labels = c("No" = "Non Churner", "Yes" = "Churner")
  ) +
  labs(
    x        = NULL,
    y        = NULL,
    fill     = NULL
  ) +
  # 2. On supprime le texte "No" / "Yes" sous les graphiques
  theme(
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank()
  )


# ── 6. Matrice de corrélation – variables numériques ─────────────────────────
#
# Permet d'identifier la multicolinéarité avant modélisation.
# Des corrélations fortes (> 0.8) peuvent justifier step_corr() ou PCA.

cor_matrix <- data |>
  select(where(is.numeric)) |>
  cor(use = "pairwise.complete.obs", method = "pearson")

var_ordre <- rownames(cor_matrix)

cor_long <- cor_matrix |>
  as.data.frame() |>
  rownames_to_column("Var1") |>
  pivot_longer(-Var1, names_to = "Var2", values_to = "r") |>
  # Triangle inférieur par position dans la matrice (comparaison positionnelle,
  # pas lexicographique — évite les artefacts si les noms ne sont pas triés).
  filter(match(Var1, var_ordre) >= match(Var2, var_ordre))

ordre_variables <- unique(cor_long$Var1)
cor_long$Var1 <- factor(cor_long$Var1, levels = ordre_variables)
cor_long$Var2 <- factor(cor_long$Var2, levels = rev(ordre_variables))

abreviations <- c(
  "Call Failure"            = "Call Fail.",
  "Customer Value"          = "Cust. Val.",
  "Distinct Called Numbers" = "Dist. Call",
  "Frequency of SMS"        = "Freq. SMS",
  "Frequency of use"        = "Freq. Use",
  "Seconds of Use"          = "Sec. Use",
  "Subscription Length"     = "Sub. Len."
)

plot_correlation <- ggplot(cor_long, aes(x = Var1, y = Var2, fill = r)) +
  geom_tile(colour = "white", linewidth = 0.3) +
  geom_text(
    aes(
      label = sprintf("%.2f", r),
      # Correction ici : on utilise r directement, pas cor_long$r
      colour = abs(r) > 0.6
    ),
    size = 2.2
  ) +
  # On définit les couleurs du texte séparément pour être plus propre
  scale_colour_manual(values = c("TRUE" = "white", "FALSE" = "grey30"), guide = "none") +
  scale_x_discrete(labels = abreviations) +
  scale_y_discrete(labels = abreviations) +
  scale_fill_gradient2(
    low      = "#185FA5",
    mid      = "white",
    high     = "#A32D2D",
    midpoint = 0,
    limits   = c(-1, 1),
    name     = NULL
  ) +
  coord_equal() +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1, size = 7.5),
    axis.text.y = element_text(size = 7.5),
    panel.grid = element_blank(),
    legend.key.height = unit(0.6, "cm")
  ) +
  labs(x = NULL, y = NULL)


# ── 7. Variables catégorielles – taux de churn par modalité ──────────────────
#
# Pour chaque variable catégorielle (hors Churn), on visualise le taux de
# churn par modalité. Révèle les variables à fort effet groupe.

vars_cat <- data |>
  select(where(is.factor), -Churn) |>
  names()

plot_cat_churn <- data |>
  select(all_of(vars_cat), Churn) |>
  pivot_longer(-Churn,
    names_to = "Variable", values_to = "Modalite",
    values_transform = as.character
  ) |>
  mutate(
    Modalite = case_when(
      Variable == "Charge  Amount" ~ factor(Modalite, levels = as.character(0:10)),
      Variable == "Age Group" ~ factor(Modalite, levels = as.character(1:5)),
      TRUE ~ factor(Modalite)
    )
  ) |>
  group_by(Variable, Modalite, Churn) |>
  summarise(n = n(), .groups = "drop") |>
  group_by(Variable, Modalite) |>
  mutate(pct = n / sum(n) * 100) |>
  ggplot(aes(x = Modalite, y = pct, fill = Churn)) +
  geom_col(position = "stack", width = 0.6) +
  facet_wrap(~Variable, scales = "free_x", ncol = 3) +
  scale_fill_manual(values = couleurs_churn, labels = c("No" = "Non Churner", "Yes" = "Churner")) +
  scale_y_continuous(labels = scales::label_percent(scale = 1), ) +
  labs(
    x        = NULL,
    y        = NULL,
    fill     = NULL
  ) +
  theme(axis.text.x = element_text(angle = 0, hjust = 0.5, vjust = 0.5, size = 8))

# ── Nettoyage de l'environnement ─────────────────────────────────────────────

rm(list = setdiff(ls(), c(
  "data",
  "tableau_presentation_donnees",
  "tableau_summary_num",
  "tableau_summary_cat",
  "plot_desequilibre",
  "plot_dist_num",
  "plot_boxplot_churn",
  "plot_correlation",
  "plot_cat_churn",
  "couleurs_churn" # conserver la palette pour graphique suivants
)))
