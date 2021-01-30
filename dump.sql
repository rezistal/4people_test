CREATE DATABASE work;

USE work;

DROP TABLE IF EXISTS log_check_user;
CREATE TABLE log_check_user (
  dt timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  idUser int(11) DEFAULT NULL,
  idAction int(11) DEFAULT NULL,
  IncomingParams json DEFAULT NULL,
  OtherParams json DEFAULT NULL,
  Message smallint(6) DEFAULT NULL
);

DROP TABLE IF EXISTS currencies;
CREATE TABLE currencies (
	id_currency smallint(6) UNSIGNED NOT NULL AUTO_INCREMENT,
	name_currency varchar(255) DEFAULT NULL,
	base_rate decimal(15, 5) DEFAULT NULL COMMENT 'курс к рублю',
	PRIMARY KEY (id_currency)
)
ENGINE = INNODB;

DROP TABLE IF EXISTS countries;
CREATE TABLE countries (
	id_country smallint(6) UNSIGNED NOT NULL AUTO_INCREMENT,
	name_country varchar(50) DEFAULT NULL,
	PRIMARY KEY (id_country)
)
ENGINE = INNODB;

DROP TABLE IF EXISTS type_opers;
CREATE TABLE type_opers (
	id_type_oper smallint(6) UNSIGNED NOT NULL AUTO_INCREMENT,
	name_oper varchar(255) DEFAULT NULL,
	comission decimal(5, 2) DEFAULT NULL COMMENT 'Процент комиссии за операцию',
	PRIMARY KEY (id_type_oper)
)
ENGINE = INNODB;

DROP TABLE IF EXISTS users;
CREATE TABLE users (
	id_user int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
	id_currency smallint(6) UNSIGNED NOT NULL,
	id_country smallint(6) UNSIGNED NOT NULL,
	PRIMARY KEY (id_user)
)
ENGINE = INNODB;

DROP TABLE IF EXISTS operations;
CREATE TABLE operations (
	id_operation bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
	dt timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_user int(11) UNSIGNED NOT NULL,
	id_type_oper smallint(6) UNSIGNED NOT NULL,
    move tinyint(4) NOT NULL COMMENT 'направление движения (-1 - со счёта, 1 - на счёт)',
	amount_oper decimal(19, 5) NOT NULL COMMENT 'Сумма операции в валюте пользователя',
	PRIMARY KEY (id_operation)
)
ENGINE = INNODB;
