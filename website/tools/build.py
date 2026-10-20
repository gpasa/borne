#!/usr/bin/env python3
"""Assemble le site de Borne (borne.pasahome.org), en français et en anglais.

Repris, en plus simple, des sites de TreeLevel et de Laue : une adresse par page ; à la racine
(/guide/, /jeux/…), la langue vient du choix explicite (?lang=), puis du témoin posé lors de ce
choix, puis d'Accept-Language, puis l'anglais ; sous /lang/<code>/ chaque page a aussi une
adresse fixe par langue, canonique et indexable (hreflang, sitemap).

Sources : src/*.html en français, src/lang/en/*.html en anglais. Chaque source commence par
    <!-- title: Guide | description: … -->
Engendre : pages/<code>/ (pages servies à la racine), pages/lang-<code>/ (pages des adresses
fixes), les dossiers d'adresses propres (index.php), render.php, .htaccess, sitemap.xml,
robots.txt, 404.html.

    python3 tools/build.py

Mise en ligne : tout le dossier sauf src/ et tools/ (le compteur, include-counter.php, reste sur
le serveur, hors du dépôt public).
"""
import os, re, json, shutil, hashlib, datetime

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SITE_URL = "https://borne.pasahome.org"
LANGS = ["fr", "en"]
SOURCE_LANG = "fr"
FALLBACK_LANG = "en"
DL_AS = "https://github.com/gpasa/borne/releases/latest/download/Borne-AppleSilicon.zip"
DL_INTEL = "https://github.com/gpasa/borne/releases/latest/download/Borne-Intel.zip"
REPO = "https://github.com/gpasa/borne"
KOFI = "https://ko-fi.com/gpasa"
PAYPAL = "https://paypal.me/GuglielmoPasa"

# Pages, dans l'ordre de la navigation ; adresse propre (vide pour l'accueil).
PAGES = {
    "index.html": "",
    "guide.html": "guide/",
    "guide-arcade.html": "guide/arcade/",
    "guide-pc.html": "guide/jeux-pc/",
    "jeux.html": "jeux/",
    "assistance.html": "assistance/",
}
NAV = ["index.html", "guide.html", "jeux.html", "assistance.html"]
GUIDE = ["guide.html", "guide-arcade.html", "guide-pc.html"]

T = {
    "fr": dict(locale="fr_FR", nav=["Accueil", "Guide", "Jeux PC", "Assistance"],
               guide=["Premiers pas", "Arcade", "Jeux PC"], skip="Aller au contenu",
               nav_label="Navigation principale", guide_label="Parties du guide", other="English",
               dl="Télécharger", dl_as="Apple silicon", dl_intel="Intel",
               donate="Borne est libre et gratuit. Si vous l'aimez, un don aide à le faire évoluer :",
               thanks="Merci !", source="Code source",
               footer="© 2026 Guglielmo Pasa · GPL-3.0 · MAME est une marque de Gregory Ember ; Borne est un projet indépendant.",
               nf=("Page introuvable", "Cette page n'existe pas ou a été déplacée.", "Retour à l'accueil"),
               tagline="votre salle d'arcade sur Mac"),
    "en": dict(locale="en_US", nav=["Home", "Guide", "PC games", "Support"],
               guide=["Getting started", "Arcade", "PC games"], skip="Skip to content",
               nav_label="Main navigation", guide_label="Guide sections", other="Français",
               dl="Download", dl_as="Apple silicon", dl_intel="Intel",
               donate="Borne is free. If you enjoy it, a donation helps it keep growing:",
               thanks="Thank you!", source="Source code",
               footer="© 2026 Guglielmo Pasa · GPL-3.0 · MAME is a trademark of Gregory Ember; Borne is an independent project.",
               nf=("Page not found", "This page does not exist or has moved.", "Back to the home page"),
               tagline="your arcade room on the Mac"),
}

TEMPLATE = """<!doctype html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{full_title}</title>
<meta name="description" content="{description}">
<link rel="canonical" href="{canonical}">
{alternates}
<meta property="og:type" content="website">
<meta property="og:site_name" content="Borne">
<meta property="og:locale" content="{locale}">
<meta property="og:title" content="{full_title}">
<meta property="og:description" content="{description}">
<meta property="og:url" content="{canonical}">
<meta property="og:image" content="{site}/images/og-image.png">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" type="image/png" href="{base}favicon.png">
<link rel="apple-touch-icon" href="{base}icon.png">
<link rel="stylesheet" href="{base}style.css?v={css_v}">
<script type="application/ld+json">{jsonld}</script>
</head>
<body>
<a class="skip" href="#main">{skip}</a>
<header class="haut">
  <div class="barre">
    <a class="marque" href="{home}"><img src="{base}icon.png" alt="" width="30" height="30"> Borne</a>
    <nav aria-label="{nav_label}">{nav}</nav>
    <a class="langue" href="{other_href}" hreflang="{other_lang}" lang="{other_lang}">{other}</a>
  </div>
</header>
<main id="main">
{guide_tabs}{body}
</main>
<footer class="bas">
  <div class="colonne">
    <p class="actions">
      <a class="cta" href="{dl_as_url}">{dl} · {dl_as}</a>
      <a class="cta secondaire" href="{dl_intel_url}">{dl} · {dl_intel}</a>
      <a class="lien" href="{repo}">{source}</a>
    </p>
    <p class="don">{donate} <a href="{kofi}">Ko-fi</a> · <a href="{paypal}">PayPal</a>. {thanks}</p>
    <p class="legal">{footer}</p>
  </div>
</footer>
</body>
</html>
"""

RENDER = """<?php
// Engendré par tools/build.py. Sert une page dans la langue du visiteur : ?lang= (posé en témoin),
// puis le témoin, puis Accept-Language, puis l'anglais. Une adresse fixe par langue (lang/<code>/…)
// passe $force avant d'inclure ce fichier.
$langues = [%(langs)s];
$routes = [%(routes)s];

if (isset($force)) {
    $choix = $force;
    $dossier = 'lang-' . $force;
} else {
    $chemin = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
    $fin = trim(preg_replace('#/index\\.php$#', '', $chemin), '/');
    $page = 'index.html';
    $meilleure = -1;
    foreach ($routes as $route => $nom) {
        $r = trim($route, '/');
        if ($r === '' ? $meilleure < 0 : ($fin === $r || str_ends_with($fin, '/' . $r)) && strlen($r) > $meilleure) {
            $page = $nom;
            $meilleure = strlen($r);
        }
    }
    if (isset($_GET['lang']) && in_array($_GET['lang'], $langues, true)) {
        setcookie('lang', $_GET['lang'], ['expires' => time() + 31536000, 'path' => '/', 'samesite' => 'Lax']);
        header('Location: ' . $chemin, true, 303);
        exit;
    }
    $choix = '%(fallback)s';
    if (isset($_COOKIE['lang']) && in_array($_COOKIE['lang'], $langues, true)) {
        $choix = $_COOKIE['lang'];
    } else {
        $meilleur = 0.0;
        foreach (explode(',', $_SERVER['HTTP_ACCEPT_LANGUAGE'] ?? '') as $morceau) {
            $parts = explode(';q=', trim($morceau));
            $racine = strtolower(explode('-', trim($parts[0]))[0]);
            $poids = isset($parts[1]) ? (float) $parts[1] : 1.0;
            if (in_array($racine, $langues, true) && $poids > $meilleur) { $meilleur = $poids; $choix = $racine; }
        }
    }
    $dossier = $choix;
}

$fichier = __DIR__ . '/pages/' . $dossier . '/' . $page;
if (!is_file($fichier)) { http_response_code(404); readfile(__DIR__ . '/404.html'); exit; }

// Compteur de visites commun aux sites pasahome.org : sur le serveur, absent du dépôt public.
$name = $page === 'index.html' ? 'borne' : 'borne-' . substr($page, 0, -5);
if (is_file(__DIR__ . '/include-counter.php')) { require __DIR__ . '/include-counter.php'; }

header('Content-Type: text/html; charset=utf-8');
header('Content-Language: ' . $choix);
if (!isset($force)) { header('Vary: Accept-Language, Cookie'); }
readfile($fichier);
"""

HTACCESS = """# Engendré par tools/build.py — ne pas modifier à la main.
AddDefaultCharset utf-8
ErrorDocument 404 /404.html
DirectoryIndex index.php index.html
RedirectMatch 404 ^/(src|tools|pages)/
<IfModule mod_expires.c>
  ExpiresActive On
  ExpiresByType image/png "access plus 30 days"
  ExpiresByType text/css "access plus 7 days"
</IfModule>
"""

NOT_FOUND = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Page not found — Borne</title>
<meta name="robots" content="noindex">
<link rel="stylesheet" href="/style.css?v={css_v}">
</head>
<body>
<main id="main">
<h1>{en[0]} · <span lang="fr">{fr[0]}</span></h1>
<p>{en[1]} <a href="/">{en[2]}</a>.</p>
<p lang="fr">{fr[1]} <a href="/?lang=fr">{fr[2]}</a>.</p>
</main>
</body>
</html>
"""


def fingerprint(name):
    return hashlib.sha1(open(os.path.join(ROOT, name), "rb").read()).hexdigest()[:10]


def read(code, name):
    path = os.path.join(ROOT, "src", name) if code == SOURCE_LANG else os.path.join(ROOT, "src", "lang", code, name)
    text = open(path, encoding="utf-8").read()
    m = re.match(r"\s*<!--\s*title:\s*(.*?)\s*\|\s*description:\s*(.*?)\s*-->\s*", text, re.S)
    if not m:
        raise SystemExit(f"{path} : commentaire title | description manquant")
    return m.group(1), m.group(2), text[m.end():]


def lang_url(code, name):
    return f"lang/{code}/{PAGES[name]}"


def build():
    css_v = fingerprint("style.css")
    for d in ["pages", "lang"] + sorted({p.split("/")[0] for p in PAGES.values() if p}):
        shutil.rmtree(os.path.join(ROOT, d), ignore_errors=True)

    sitemap = []
    for code in LANGS:
        t = T[code]
        other = [c for c in LANGS if c != code][0]
        for name, slug in PAGES.items():
            title, description, body = read(code, name)
            for variant in ("root", "lang"):
                # Chemin relatif de la page jusqu'à la racine du site.
                where = slug if variant == "root" else lang_url(code, name)
                base = "../" * where.count("/")

                def href(target):
                    return base + (PAGES[target] if variant == "root" else lang_url(code, target)) or "./"

                current = "guide.html" if name in GUIDE else name
                nav = "".join(
                    f'<a href="{href(p)}"{" aria-current=\"page\"" if p == current else ""}>{label}</a>'
                    for p, label in zip(NAV, t["nav"]))
                tabs = ""
                if name in GUIDE:
                    tabs = ('<nav class="onglets" aria-label="%s">' % t["guide_label"] + "".join(
                        f'<a href="{href(p)}"{" aria-current=\"page\"" if p == name else ""}>{label}</a>'
                        for p, label in zip(GUIDE, t["guide"])) + "</nav>\n")
                # Liens internes des sources : href="@page.html" (ou "@page.html#ancre").
                html = re.sub(r'href="@([a-z-]+\.html)(#[^"]*)?"',
                              lambda m: f'href="{href(m.group(1))}{m.group(2) or ""}"', body)
                html = html.replace('src="@', f'src="{base}').replace("@DL_AS@", DL_AS).replace("@DL_INTEL@", DL_INTEL)
                other_href = (base + PAGES[name] + f"?lang={other}") if variant == "root" else base + lang_url(other, name)
                canonical = f"{SITE_URL}/{lang_url(code, name)}"
                alternates = "\n".join(
                    [f'<link rel="alternate" hreflang="{c}" href="{SITE_URL}/{lang_url(c, name)}">' for c in LANGS]
                    + [f'<link rel="alternate" hreflang="x-default" href="{SITE_URL}/{slug}">'])
                full_title = f"Borne — {t['tagline']}" if name == "index.html" else f"{title} — Borne"
                jsonld = {"@context": "https://schema.org", "@type": "SoftwareApplication", "name": "Borne",
                          "operatingSystem": "macOS 14+", "applicationCategory": "GameApplication",
                          "offers": {"@type": "Offer", "price": "0", "priceCurrency": "CHF"},
                          "license": "https://www.gnu.org/licenses/gpl-3.0.html", "downloadUrl": f"{REPO}/releases/latest",
                          "inLanguage": code, "url": canonical,
                          "author": {"@type": "Person", "@id": "https://pasahome.org/#person", "name": "Guglielmo Pasa"}}
                page = TEMPLATE.format(
                    lang=code, full_title=full_title, description=description, canonical=canonical,
                    alternates=alternates, locale=t["locale"], site=SITE_URL, base=base, css_v=css_v,
                    jsonld=json.dumps(jsonld, ensure_ascii=False), skip=t["skip"], home=href("index.html"),
                    nav_label=t["nav_label"], nav=nav, other_href=other_href, other_lang=other, other=t["other"],
                    guide_tabs=tabs, body=html.strip(), dl_as_url=DL_AS, dl_intel_url=DL_INTEL, dl=t["dl"],
                    dl_as=t["dl_as"], dl_intel=t["dl_intel"], repo=REPO, source=t["source"], donate=t["donate"],
                    kofi=KOFI, paypal=PAYPAL, thanks=t["thanks"], footer=t["footer"])
                folder = code if variant == "root" else f"lang-{code}"
                os.makedirs(os.path.join(ROOT, "pages", folder), exist_ok=True)
                open(os.path.join(ROOT, "pages", folder, name), "w", encoding="utf-8").write(page)
            # Adresse fixe : lang/<code>/<page>/index.php.
            d = os.path.join(ROOT, lang_url(code, name))
            os.makedirs(d, exist_ok=True)
            depth = lang_url(code, name).count("/")
            open(os.path.join(d, "index.php"), "w", encoding="utf-8").write(
                f"<?php\n$force = '{code}';\n$page = '{name}';\nrequire dirname(__DIR__, {depth}) . '/render.php';\n")
            sitemap.append((code, name))

    # Adresses négociées à la racine : /guide/index.php… et /index.php.
    for name, slug in PAGES.items():
        d = os.path.join(ROOT, slug)
        os.makedirs(d, exist_ok=True)
        depth = slug.count("/")
        target = "__DIR__" if depth == 0 else f"dirname(__DIR__, {depth})"
        open(os.path.join(d, "index.php"), "w", encoding="utf-8").write(f"<?php\nrequire {target} . '/render.php';\n")

    routes = ", ".join(f"'{slug}' => '{name}'" for name, slug in PAGES.items())
    open(os.path.join(ROOT, "render.php"), "w", encoding="utf-8").write(
        RENDER % {"langs": ", ".join(f"'{c}'" for c in LANGS), "routes": routes, "fallback": FALLBACK_LANG})
    open(os.path.join(ROOT, ".htaccess"), "w", encoding="utf-8").write(HTACCESS)
    open(os.path.join(ROOT, "404.html"), "w", encoding="utf-8").write(
        NOT_FOUND.format(css_v=css_v, en=T["en"]["nf"], fr=T["fr"]["nf"]))
    today = datetime.date.today().isoformat()
    urls = []
    for code, name in sitemap:
        alts = "".join(f'<xhtml:link rel="alternate" hreflang="{c}" href="{SITE_URL}/{lang_url(c, name)}"/>' for c in LANGS)
        urls.append(f"<url><loc>{SITE_URL}/{lang_url(code, name)}</loc><lastmod>{today}</lastmod>{alts}</url>")
    open(os.path.join(ROOT, "sitemap.xml"), "w", encoding="utf-8").write(
        '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" '
        'xmlns:xhtml="http://www.w3.org/1999/xhtml">\n' + "\n".join(urls) + "\n</urlset>\n")
    open(os.path.join(ROOT, "robots.txt"), "w", encoding="utf-8").write(
        f"User-agent: *\nDisallow: /pages/\nDisallow: /src/\nDisallow: /tools/\nSitemap: {SITE_URL}/sitemap.xml\n")
    print(f"{len(sitemap)} pages ({', '.join(LANGS)}), render.php, .htaccess, sitemap.xml, robots.txt, 404.html")


if __name__ == "__main__":
    build()
