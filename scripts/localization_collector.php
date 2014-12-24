<?php

/*
	Author: Hizuro <hizuro@gmx.net>
*/

define("SD",dirname(__FILE__).'/'); // SD (script directory)
require SD.'/shared.php';

/* string collector */
$strings = array();
foreach($files as $f){
	$path_file=$f[0]; $file_name=str_replace(".lua","",$f[1]);
	$d=str_replace("\"","'",file_get_contents($path_file));
	preg_match_all("/L\['(.*)']/Um",$d,$m);
	foreach($m[1] as $str){
		if($str!=""){
			if(!isset($strings[$str])){
				$strings[$str] = array();
			}
			$strings[$str][$file_name]=true;
		}
	}
}
ksort($strings);

/* ?? */
$byFiles = array();  $plaintext = "";
foreach($strings as $str=>$files){
	if(is_array($files) && count($files)>1){
		$byFiles['shared'][$str] = $files;
	}else{
		$files = array_keys($files);
		$byFiles[$files[0]][$str] = true;
	}
	$plaintext .= $str."\n";
}
ksort($byFiles);

/* lua generator */

$lua = "--[[ shared ]]\n";
foreach($byFiles['shared'] as $str=>$files){
	if(is_array($files) and !isset($files['localizations'])){
		$lua .= "L[\"{$str}\"] = \"\" -- ".implode(".lua, ",array_keys($files)).".lua\n";
	} else {
		$lua .= "L[\"{$str}\"] = \"\" -- shared.lua\n";
	}
}
foreach($byFiles as $file=>$strs){
	if($file!="shared"){
		$lua .= "\n--[[ {$file} ]]\n";
		foreach($strs as $str=>$x){
			$lua .= "L[\"{$str}\"] = \"\"\n";
		}
	}
}


file_put_contents(SD."example_localization.lua",$lua);
file_put_contents(SD."example_localization.txt",$plaintext);

?>
<!DOCTYPE html>
<html>
<head></head>
<body>
<h4>Script finished!</h4>
<div>example_localization.lua and example_localization.txt successfully created in <?php echo SD; ?>.</div>
</body>
</html>