# Icône provisoire (M7)

Remplacée par l'icône Blason (`Design/Blason`) ; `AppIcon.appiconset` a été retiré du projet.

Feuille + dé, en attendant la réflexion sur le nom de l'app et son icône.

`python3 make.py .` régénère les SVG ; les PNG de `AppIcon.appiconset` en sont tirés avec
`rsvg-convert -w 1024 -h 1024`, puis repassés en JPEG puis PNG pour retirer le canal alpha.
