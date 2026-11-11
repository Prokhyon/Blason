# Icône Blason (pistes)

Sources en calques pour **Icon Composer** (iOS 26), à tester avant de choisir.

`python3 make.py .` régénère tous les dossiers et les planches. Les dossiers de pistes sont générés : ils sont recréés à chaque fois, n'y mettez rien à la main.

## Forme retenue

**`Chef-Elance-32-l12`** : un vrai d10 incliné de 32°, allongé ×1,4, élargi de 12 %, avec deux coins qui lui donnent un chef plat.

Couleurs (`planche-couleurs-…`, palettes `HUES`, `CONTRASTS`, `HUES_GOLD`, `HUES_SILVER` dans `make.py`) :

- contraste « actuel » : coins entre le fond et le dé, face à l'inverse du fond ; surtout pas de coins proches du dé ;
- huit teintes (terre cuite, gueules, or, sinople, sarcelle, azur, pourpre, graphite), candidates pour des icônes alternatives au choix dans l'app ;
- coins en métal héraldique (or ou argent) à étudier ; pas de métal sur métal (la teinte Or prend des coins d'argent).

**Pour essayer dans Icon Composer : le dossier [`Finale`](Finale/README.md)**, une version par teinte (unie, ou avec des coins en or), avec les calques à importer et les couleurs de chaque apparence. Choix faits : or « +2 » en sombre (`#BA7517`), fond crème.

Position : descendu de 2 unités (32 px), parce que le chef plat et la pointe le faisaient paraître haut. Les autres positions essayées sont sur `planche-position`.

**Les icônes : le dossier [`Icones`](Icones)**, un document Icon Composer par teinte (`Blason-<teinte>.icon`). Chacun contient les trois calques, chacun dans son groupe de verre, avec les couleurs claires et sombres, et le fond crème ou sombre. Ils s'ouvrent dans Icon Composer. `make.py` les installe aussi dans l'app : `Character Sheet/AppIcon.icon` pour l'icône principale (`MAIN_ICON`, terre cuite unie) et `Character Sheet/AppIcons/AppIcon-<teinte>.icon` pour les quinze alternatives, déclarées dans `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` du projet (à mettre à jour si la liste change). Le teinté et le transparent sont calculés par le système. Si Icon Composer est installé, `make.py` en tire le vrai rendu avec `ictool` : `Icones/Rendus` et `planche-icones.png` (clair, sombre, teinté sombre, transparent clair). Les réglages du verre (translucidité 0,5, ombre neutre 0,5) sont dans `icon_document`.

Exemples à plusieurs couches (`planche-couches`, calques dans [`Couches`](Couches)) : verre sur chaque groupe, un « 0 » de dé sur la face, des coins dépolis, ou une plaque en forme d'écu derrière le dé. L'aperçu simule grossièrement le verre (ombre, reflet, transparence) ; le vrai rendu se voit dans Icon Composer, en mettant chaque calque dans son propre groupe.

## Les pistes (`DESIGNS` dans `make.py`)

- `2b` : écu en blocs (en-tête, deux colonnes dont une avec le portrait en creux, pointe).
- `N1-…` : écu facetté comme un d10, dessiné à la main :
  - A actuelle, B côtés en pointe, H, I, J entre A et B ;
  - C moins allongée, D = C avec les côtés en pointe ;
  - E trapue, E-bas la même pointe en bas ;
  - F chef plat, G écu arrondi.
- `Bas-25` : un vrai d10 projeté, pointe en bas, incliné de 25°.
- `Chef-C`, `Chef-Elance`, `Chef-E-bas`, `Chef-Bas-25` : le dé en couleur, avec deux coins qui lui donnent un chef plat (forme de F). Trois rôles : les coins (entre le fond et le dé en luminosité), le dé, et la face principale (à l'inverse du fond : foncée en clair, claire en sombre).
- `D20-ecu` : écu taillé comme un d20.
- `D10-ecu`, `D10-ecu-accent` : un écu simple avec un petit d10 au milieu.

## Les planches

Chaque planche montre les pistes en clair, sombre et teinté, puis en 29 pt.

- `planche-selection` : la sélection en cours.
- `planche-chef-plat` : les essais à chef plat.
- `planche` : 2b et les premières formes de N1.

`explore.py` dessine une planche d'exploration (`exploration-d10.svg` et `.png`, version claire) : un vrai d10 projeté sous plein d'angles, pointe en haut ou en bas, de trois quarts, avec d'autres proportions, taillé dans un écu, ombré… Chaque variante est une ligne de paramètres dans `FAMILIES`. `make.py` réutilise la même projection.

## Importer dans Icon Composer

1. Nouveau document, puis glisser les SVG d'un dossier dans l'ordre de leur numéro (le 1 tout en bas).
2. Fond : `#F4F2EC` en clair, `#1F1F1D` en sombre.
3. Couleurs par apparence (clair / sombre) :

   | Rôle | Clair | Sombre |
   |---|---|---|
   | encre | `#2C2C2A` | `#E8E6DF` |
   | accent | `#D85A30` | `#F0997B` |
   | accent foncé | `#993C1D` | `#D85A30` |
   | accent clair | `#F0997B` | `#F5C4B3` |
   | coins | `#F0997B` | `#993C1D` |
   | dé | `#D85A30` | `#D85A30` |
   | face | `#712B13` | `#F5C4B3` |

   Le mode teinté se calcule seul.
4. Le verre, les reflets et la profondeur viennent d'Icon Composer : les calques restent des aplats, sans ombre ni dégradé.

Les formes sont dessinées sur une grille de 64 (×16 = 1024). L'interstice entre facettes (`GAP`) et l'arrondi des coins (`RADIUS`) se règlent en tête de `make.py`.
