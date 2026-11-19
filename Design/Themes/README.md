# Thèmes décorés (pistes)

Brainstorming du 19 novembre 2026 : des thèmes plus proches des fiches de personnage imprimées,
avec bordures ornées et enluminures. Six directions, toutes retenues. Réalisées : **Enluminure**
(`Blason/Themes/IlluminatedTheme.swift`), **Armorial** (`Blason/Themes/ArmorialTheme.swift`) et
**Grimoire** (`Blason/Themes/GrimoireTheme.swift`).

On s'inspire des **genres** (manuscrit, héraldique, Art déco…), jamais d'une fiche officielle
d'éditeur.

## Les six directions

| Thème | Ambiance | Pièces caractéristiques | Clair / sombre |
|---|---|---|---|
| **Enluminure** | manuscrit médiéval sur vélin | lettrine dorée sur fond d'émail, rinceaux en marge de page, titres rubriqués (rouge), pied-de-mouche ¶ devant les libellés, palette des émaux | clair |
| **Armorial** | héraldique | titre de section sur une banderole aux émaux, cadres à double filet doré, fleurons ✥ aux coins, titre de page dans un cartouche | clair |
| **Grimoire** | cuir sombre, encre d'or | titres centrés en capitales dorées, filet d'or, coins de reliure en laiton, séparateur « — ✦ — » | **sombre** |
| **Carte & journal de bord** | carte au trésor, pirates | parchemin sépia, bordure en corde (tirets), rose des vents en coin, titres manuscrits (Snell Roundhand) | clair |
| **Dossier 1920** | enquêteur, L'Appel de Cthulhu (BRP) | cadres Art déco à coins coupés, bandeau de titre noir en capitales espacées (Futura), machine à écrire (American Typewriter), tampon « CONFIDENTIEL » | clair |
| **Entrelacs** | celtique / nordique | frises tressées en haut et bas de section, rune devant le titre (ᚲ), Optima, vert profond | clair |

## Architecture (V2.4)

Les pièces ajoutées à `SheetTheme` pour ces thèmes, chacune avec une valeur native par défaut :
cadre de page (`pageFrame`), titre de page (`pageTitle`), en-tête de groupe (`groupHeader`),
cadre de tuile (`tileFrame`), séparateur (`divider`), police et couleur des libellés. Le cadre de
section reçoit aussi le texte brut du titre et sa place dans la page (lettrine sur la première).

Le kit `Blason/Themes/Ornaments/` réunit ce qui se partage d'un thème à l'autre : grain,
lettrine, rinceau, cadre en 9 parties dessiné une fois puis étiré (coins fixes, bords étirés),
cache d'images par émail, émaux et or (`Heraldry`).

Chaque thème peut avoir sa **palette** : les thèmes décorés prennent les émaux des icônes de l'app
(Gueules, Azur, Sinople, Pourpre, Sable…), mêmes couleurs que `Design/Blason/make.py`.

## Polices

La SPEC (§5.9) s'en tient aux polices d'iOS. Elles suffisent pour la plupart des pistes
(Copperplate, Baskerville, Big Caslon, Cochin, Snell Roundhand, Optima, American Typewriter,
Futura). Il n'y a ni gothique ni onciale sur iOS : pour un vrai style manuscrit, il faudrait
embarquer des polices libres (OFL), par exemple Cinzel, IM Fell English, EB Garamond ou
UnifrakturMaguntia.
