<?php
require __DIR__ . '/vendor/autoload.php';
require __DIR__ . '/inc/DB.php';
require __DIR__ . '/inc/Config.php';
require __DIR__ . '/inc/VpnServer.php';
require __DIR__ . '/inc/InstallProtocolManager.php';

$server = new VpnServer(5);
$stmt = DB::conn()->query("SELECT * FROM protocols WHERE slug = 'openvpn-cloak'");
$proto = $stmt->fetch();

$result = InstallProtocolManager::install($server, $proto);
echo json_encode($result, JSON_PRETTY_PRINT);
