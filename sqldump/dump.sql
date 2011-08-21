CREATE TABLE `proxylist` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `host` varchar(15) NOT NULL,
  `port` smallint(5) unsigned NOT NULL,
  `checked` tinyint(1) NOT NULL DEFAULT '0',
  `worked` tinyint(1) NOT NULL DEFAULT '0',
  `checkdate` datetime NOT NULL DEFAULT '1980-01-01 00:00:00',
  `fails` tinyint(1) NOT NULL DEFAULT '0',
  `type` enum('HTTP_PROXY','SOCKS4_PROXY','SOCKS5_PROXY','DEAD_PROXY') NOT NULL DEFAULT 'DEAD_PROXY',
  `in_progress` tinyint(1) NOT NULL DEFAULT '0',
  `conn_time` smallint(5) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `proxy` (`host`,`port`),
  KEY `sort` (`checked`,`checkdate`),
  KEY `type` (`type`)
) ENGINE=MyISAM AUTO_INCREMENT=135108 DEFAULT CHARSET=latin1
