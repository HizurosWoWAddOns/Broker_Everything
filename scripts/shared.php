<?php

/*
	Author: Hizuro <hizuro@gmx.net>
*/

define("BD",dirname(dirname(__FILE__)).'/'); // BD (base directory)

/* directory crawler */
$files = array();
foreach(array("","modules/") as $dir){
	if($dh=opendir(BD.$dir)){
		while($f=readdir($dh)){
			if(is_file(BD.$dir.$f) && filesize(BD.$dir.$f)>0 && preg_match("/^.*\.lua$/is",$f)){
				$files[] = array(BD.$dir.$f,$f);
			}
		}
		closedir($dh);
	}
}
