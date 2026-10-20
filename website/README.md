# Site de Borne

`https://borne.pasahome.org`, en français et en anglais, sur le modèle des sites de TreeLevel et de Laue.

- `src/*.html` — les pages en français ; `src/lang/en/*.html` — en anglais. Chaque source commence par
  `<!-- title: … | description: … -->`. Liens internes : `href="@page.html"`, images : `src="@images/…"`.
- `tools/build.py` — assemble `pages/` (pages servies), les adresses propres (`guide/`, `jeux/`…, langue
  choisie par `?lang=`, le témoin, puis `Accept-Language`, sinon l'anglais), `lang/<code>/…` (adresse fixe par
  langue, canonique), `render.php`, `.htaccess`, `sitemap.xml`, `robots.txt`, `404.html`.
- `images/` — captures de Borne (`open --args -selectGame gridlee`, `-selectFolder quake2`, `-openSettings YES
  -settingsTab data`) ; pas d'image de jeu commercial.

```bash
python3 tools/build.py
```

Aperçu local : `http://localhost/~gpasa/www/apps/borne/` (PHP nécessaire).

Mise en ligne : tout le dossier **sauf `src/`, `tools/` et ce README**, à la racine de `borne.pasahome.org`,
avec `.htaccess`. Le compteur (`include-counter.php`) reste sur le serveur, hors du dépôt public.
