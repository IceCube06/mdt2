CREATE TABLE `mdt_records` (
    `identifier` varchar(60) NOT NULL,
    `description` longtext NOT NULL,
    `date_added` varchar(60) NOT NULL,
    `author` varchar(60) NOT NULL,
    `fine_amount` int(11) NOT NULL,
    `fine_prison` int(11) NOT NULL,
    `fines` longtext NOT NULL
);

CREATE TABLE `mdt_notes` (
    `identifier` varchar(60) NOT NULL,
    `label` longtext NOT NULL,

    PRIMARY KEY (`identifier`)
);

CREATE TABLE `mdt_warrants` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `identifier` varchar(60) NOT NULL,
    `name` varchar(255) NOT NULL,
    `description` longtext NOT NULL,
    `date_added` varchar(255) DEFAULT NULL,
	`date_expires` varchar(255) DEFAULT NULL,
	`author` varchar(255) DEFAULT NULL,

    PRIMARY KEY (`id`)
);

ALTER TABLE `users` ADD `picture` longtext NOT NULL;