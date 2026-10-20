<?php
// Engendré par tools/build.py. Sert une page dans la langue du visiteur : ?lang= (posé en témoin),
// puis le témoin, puis Accept-Language, puis l'anglais. Une adresse fixe par langue (lang/<code>/…)
// passe $force avant d'inclure ce fichier.
$langues = ['fr', 'en'];
$routes = ['' => 'index.html', 'guide/' => 'guide.html', 'guide/arcade/' => 'guide-arcade.html', 'guide/jeux-pc/' => 'guide-pc.html', 'jeux/' => 'jeux.html', 'assistance/' => 'assistance.html'];

if (isset($force)) {
    $choix = $force;
    $dossier = 'lang-' . $force;
} else {
    $chemin = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
    $fin = trim(preg_replace('#/index\.php$#', '', $chemin), '/');
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
    $choix = 'en';
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
