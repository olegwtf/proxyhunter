CREATE TABLE  `proxylist` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `host` varchar(15) NOT NULL,
  `port` smallint(5) unsigned NOT NULL,
  `checked` tinyint(4) NOT NULL DEFAULT '0',
  `checkdate` datetime NOT NULL DEFAULT '1980-01-01 00:00:00',
  `fails` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `proxy` (`host`,`port`)
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;
