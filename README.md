# 4people_test
Задача 1. Партиции
Имеется таблица логов:
CREATE TABLE work.log_check_user (
  dt timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  idUser int(11) DEFAULT NULL,
  idAction int(11) DEFAULT NULL,
  IncomingParams json DEFAULT NULL,
  OtherParams json DEFAULT NULL,
  Message smallint(6) DEFAULT NULL
)
Необходимо разбить таблицу на партиции по 1 дню и написать Event, осуществляющий ротацию партиций (добавление новых и удаление старых), оставляя например последние 2 недели. Предусмотреть ситуацию, при которой евент не отработает 1-2 дня, т.е. должны быть партиции «про запас», а так же добавление/удаление нескольких в евенте.
Подсказка: списки партиций запросом можно получить из information_schema.PARTITIONS, а собирать запросы удаления и создания  через prepared statement.

Задача 2. Отчёты и консолидация
Имеется набор таблиц. Справочники валют, стран и типо операций:
CREATE TABLE work.currencies (
	id_currency smallint(6) UNSIGNED NOT NULL AUTO_INCREMENT,
	name_currency varchar(255) DEFAULT NULL,
	base_rate decimal(15, 5) DEFAULT NULL COMMENT 'курс к рублю',
	PRIMARY KEY (id_currency)
)
ENGINE = INNODB;
CREATE TABLE work.countries (
	id_country smallint(6) UNSIGNED NOT NULL AUTO_INCREMENT,
	name_country varchar(50) DEFAULT NULL,
	PRIMARY KEY (id_country)
)
ENGINE = INNODB;
CREATE TABLE work.type_opers (
	id_type_oper smallint(6) UNSIGNED NOT NULL AUTO_INCREMENT,
	name_oper varchar(255) DEFAULT NULL,
	comission decimal(5, 2) DEFAULT NULL COMMENT 'Процент комиссии за операцию',
	PRIMARY KEY (id_type_oper)
)
ENGINE = INNODB;

пользователи:
CREATE TABLE work.users (
	id_user int(11) UNSIGNED NOT NULL AUTO_INCREMENT,
	id_currency smallint(6) UNSIGNED NOT NULL,
	id_country smallint(6) UNSIGNED NOT NULL,
	PRIMARY KEY (id_user)
)
ENGINE = INNODB;

Операции:
CREATE TABLE work.operations (
	id_operation bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
	dt timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
id_user int(11) UNSIGNED NOT NULL,
	id_type_oper smallint(6) UNSIGNED NOT NULL,
move tinyint(4) NOT NULL COMMENT 'направление движения (-1 - со счёта, 1 - на счёт)'
	amount_oper decimal(19, 5) NOT NULL COMMENT 'Сумма операции в валюте пользователя',
	PRIMARY KEY (id_operation)
)
ENGINE = INNODB;

Необходимо составить добавить необходимые индексы, а так же составить процедуры, учитывая, что транзакций миллионы в день (т.е. оптимизировать по максимуму):
1) Общий отчёт за период дат. На вход две даты, на вывод – с группировкой по стране и типу операции общая сумма, сумма комиссии, итоговая сумма (с вычетом комиссии) в рублях. Отчёт должен содержать промежуточные итоги по каждой стране, а так же строку с общим итогом.
2) Для ускорения отчёта необходимо составить евент консолидирования данных (заранее считать по дню и сохранять их в отдельную таблицу)
3) В первый отчёт добавить консолидированные данные, дотягивая только последние неотконсолидированные (текущий день) а так же старые часы перед консолидацией. Пример: для запроса с 2019-06-01 14:00:00 по 2019-06-05 14:00:00 надо взять 2,3,4 числа из консолидации и добавить к ним сырые данные за 10 часов первого числа и 14 часов пятого
4) Сделать отчёт по операциям конкретного пользователя за период дат, сгруппировать по типу операции, и строчка общих итогов
5) Отчёт о самых популярных операциях за введённый период дат. Критерием взять количество, не сумму. Отчёт на выходе должен иметь столбец с порядковым номером строки (подсказка – делается через сессионные переменные)
