<?php
declare(strict_types=1);

// Compteur de visites commun aux sites pasahome.org : présent sur le serveur,
// absent du dépôt public.
$name = 'borne';
if (is_file(__DIR__ . '/include-counter.php')) {
    require __DIR__ . '/include-counter.php';
}

readfile(__DIR__ . '/index.html');
