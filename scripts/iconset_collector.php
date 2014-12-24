<?php

/*
	Author: Hizuro <hizuro@gmx.net>
*/

define("SD",dirname(__FILE__).'/'); // SD (script directory)
require SD.'/shared.php';

$icons = array();
foreach($files as $f){
	$fp = $f[0]; $fn = $f[1];
	$d = str_replace(array("'","\""),array("",""),file_get_contents($fp));
	preg_match_all("/local (name[0-9]?) = (.*) --/iUms",$d,$names);
	if(count($names[1])>0){
		$names[1][] = "..";
		$names[2][] = "";
		$d = str_replace($names[1],$names[2],$d);
	}
	preg_match_all("/\-\-IconName::([a-zA-Z0-9_\-]+)\-\-/iUms",$d,$m);
	if(count($m[1])>0){
		foreach($m[1] as $icon){
			$icons[$icon] = true;
		}
	}
}

$lua_line = '	-- ["*"] = {iconfile=p.."", coords = #},';
$lua = array();
foreach($icons as $name => $bool){
	if(preg_match("/^gm_/",$name))
		$coords = "coordsStr";
	else
		$coords = "coords";
	$lua[] = str_replace(array("*","#"),array($name,$coords),$lua_line);
}

$lua = '
local addon, ns = ...
local p = "Interface\\Addons\\"..addon.."\\media\\"
local coords = {0,1,0,1} 
local coordsStr = "16:16:0:0"

LibStub("LibSharedMedia-3.0"):Register("Broker_Everything_Iconsets","<Your Iconset name>",{
'.implode("\n",$lua).'
})

';

file_put_contents("example_iconset.lua",$lua);

?>
<!DOCTYPE html>
<html>
<head></head>
<body>
<h4>Script finished!</h4>
<div>example_iconset.lua successfully created in <?php echo SD; ?>.</div>
</body>
</html>