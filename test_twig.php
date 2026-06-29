<?php
require_once __DIR__ . '/vendor/autoload.php';
use Twig\Environment;
use Twig\Loader\ArrayLoader;

$loader = new ArrayLoader([
    'index' => '{% if user.role in ["admin", "manager"] %}VISIBLE{% else %}HIDDEN{% endif %}',
]);
$twig = new Environment($loader);

echo $twig->render('index', ['user' => ['role' => 'manager']]);
