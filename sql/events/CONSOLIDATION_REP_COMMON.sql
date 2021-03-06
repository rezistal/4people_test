DELIMITER $$
USE work $$

DROP PROCEDURE IF EXISTS CONSOLIDATION_REP_COMMON $$
CREATE PROCEDURE CONSOLIDATION_REP_COMMON
()
CONSOLIDATION_REP_COMMON:BEGIN

  DECLARE done INT DEFAULT 0;
  DECLARE
    vMAX_REPORT_DATE,
    vMIN_OPERATION_DT,
    vCURRENT_DATE,
    vDATE_FROM,
    vDATE_TO
  DATE;
  DECLARE vOPERATIONS_IN_PACK,vCURRENT_PACK INT;

  DECLARE curpack CURSOR FOR SELECT T.PACK_NUM FROM tt_operations_packs T GROUP BY T.PACK_NUM ORDER BY T.PACK_NUM;
  DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

  SET vMAX_REPORT_DATE = (SELECT MAX(T.REPORT_DATE) FROM work.common_report_consolidation T);
  SET vMIN_OPERATION_DT = (SELECT DATE(MIN(T.DT)) FROM work.operations T);
  SET vCURRENT_DATE = DATE(NOW());

  SET vDATE_FROM = IFNULL(vMAX_REPORT_DATE + INTERVAL 1 DAY, vMIN_OPERATION_DT);

  -- Если нет операций
  IF vDATE_FROM IS NULL THEN
    LEAVE CONSOLIDATION_REP_COMMON;
  END IF;

  SET vDATE_TO = vCURRENT_DATE;

  SET vOPERATIONS_IN_PACK = 100;

  DROP TEMPORARY TABLE IF EXISTS tt_operations_packs;
  CREATE TEMPORARY TABLE tt_operations_packs
  (
    ID_NUM INT NOT NULL AUTO_INCREMENT,
    PACK_NUM INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY(`ID_NUM`)
  )
  SELECT O.DT AS REPORT_DATE,
         O.ID_OPERATION,
         O.ID_USER,
         O.ID_TYPE_OPER,
         O.MOVE,
         O.AMOUNT_OPER
  FROM work.operations O
  WHERE O.DT BETWEEN vDATE_FROM AND vDATE_TO
     ;
  CREATE INDEX idx_tt_operations_packs ON tt_operations_packs(PACK_NUM);
  CREATE INDEX idx_tt_operations_packs_type_oper ON tt_operations_packs(ID_TYPE_OPER);
  CREATE INDEX idx_tt_operations_packs_user ON tt_operations_packs(ID_USER);

  UPDATE tt_operations_packs
  SET PACK_NUM = (ID_NUM DIV vOPERATIONS_IN_PACK) + 1;

  DROP TEMPORARY TABLE IF EXISTS tt_prepare_report;
  CREATE TEMPORARY TABLE tt_prepare_report
  (
    REPORT_DATE DATE NOT NULL,
    ID_COUNTRY smallint(6) unsigned NOT NULL DEFAULT '0',
    NAME_COUNTRY varchar(50) DEFAULT '',
    ID_TYPE_OPER smallint(6) unsigned NOT NULL DEFAULT '0',
    NAME_OPER varchar(255) DEFAULT '',
    TOTAL decimal(65,16) DEFAULT NULL,
    TOTAL_DBT decimal(65,16) DEFAULT NULL,
    TOTAL_KRD decimal(65,16) DEFAULT NULL,
    TOTAL_COMMISSION decimal(65,16) DEFAULT NULL,
    TOTAL_ITOG decimal(65,16) DEFAULT NULL,
    TOTAL_ITOG_DBT decimal(65,16) DEFAULT NULL,
    TOTAL_ITOG_KRD decimal(65,16) DEFAULT NULL
  );

  SET done = 0;
  OPEN curpack;
  FETCH curpack INTO vCURRENT_PACK;
  WHILE done = 0 DO

    DROP TEMPORARY TABLE IF EXISTS tt_operations;
    CREATE TEMPORARY TABLE tt_operations AS
    SELECT O.REPORT_DATE,
           C.ID_COUNTRY,
           C.NAME_COUNTRY,
           OT.ID_TYPE_OPER,
           OT.NAME_OPER,
           O.ID_USER,
           O.MOVE,
           SUM(O.AMOUNT_OPER * IFNULL(CR.BASE_RATE, 0)) AS TOTAL, -- обороты суммарно
           SUM(IF(O.MOVE = -1, O.AMOUNT_OPER * IFNULL(CR.BASE_RATE, 0), NULL)) AS TOTAL_DBT, -- дебет
           SUM(IF(O.MOVE =  1, O.AMOUNT_OPER * IFNULL(CR.BASE_RATE, 0), NULL)) AS TOTAL_KRD, -- кредит
           SUM(O.AMOUNT_OPER * IFNULL(OT.COMISSION, 0) * IFNULL(CR.BASE_RATE, 0) / 100) AS TOTAL_COMMISSION,
           SUM(O.AMOUNT_OPER  * (100.00 - IFNULL(OT.COMISSION, 0)) * IFNULL(CR.BASE_RATE, 0) / 100) AS TOTAL_ITOG,  -- обороты пользователей суммарно
           SUM(IF(O.MOVE = -1, O.AMOUNT_OPER  * (100.00 - IFNULL(OT.COMISSION, 0)) * IFNULL(CR.BASE_RATE, 0) / 100, NULL)) AS TOTAL_ITOG_DBT, -- дебет пользователей
           SUM(IF(O.MOVE =  1, O.AMOUNT_OPER  * (100.00 - IFNULL(OT.COMISSION, 0)) * IFNULL(CR.BASE_RATE, 0) / 100, NULL)) AS TOTAL_ITOG_KRD -- кредит пользователей
    FROM tt_operations_packs  O
    JOIN work.type_opers     OT ON OT.ID_TYPE_OPER = O.ID_TYPE_OPER
    JOIN work.users           U ON U.ID_USER = O.ID_USER
    JOIN work.currencies     CR ON CR.ID_CURRENCY = U.ID_CURRENCY
    JOIN work.countries       C ON C.ID_COUNTRY = U.ID_COUNTRY
    WHERE O.PACK_NUM = vCURRENT_PACK
    GROUP BY O.REPORT_DATE, C.ID_COUNTRY, OT.ID_TYPE_OPER
    ;

    INSERT INTO tt_prepare_report
    (
      REPORT_DATE,
      ID_COUNTRY,
      ID_TYPE_OPER,
      TOTAL,
      TOTAL_DBT,
      TOTAL_KRD,
      TOTAL_COMMISSION,
      TOTAL_ITOG,
      TOTAL_ITOG_DBT,
      TOTAL_ITOG_KRD
    )
    SELECT REPORT_DATE,
           ID_COUNTRY,
           ID_TYPE_OPER,
           TOTAL,
           TOTAL_DBT,
           TOTAL_KRD,
           TOTAL_COMMISSION,
           TOTAL_ITOG,
           TOTAL_ITOG_DBT,
           TOTAL_ITOG_KRD
    FROM tt_operations;

    SET done = 0;
    FETCH curpack INTO vCURRENT_PACK;
  END WHILE;
  CLOSE curpack;

  REPLACE INTO common_report_consolidation
  (
    REPORT_DATE,
    ID_COUNTRY,
    ID_TYPE_OPER,
    TOTAL,
    TOTAL_DBT,
    TOTAL_KRD,
    TOTAL_COMMISSION,
    TOTAL_ITOG,
    TOTAL_ITOG_DBT,
    TOTAL_ITOG_KRD
  )
  SELECT T.REPORT_DATE,
         T.ID_COUNTRY,
         T.ID_TYPE_OPER,
         SUM(T.TOTAL) AS TOTAL,
         SUM(T.TOTAL_DBT) AS TOTAL_DBT,
         SUM(T.TOTAL_KRD) AS TOTAL_KRD,
         SUM(T.TOTAL_COMMISSION) AS TOTAL_COMMISSION,
         SUM(T.TOTAL_ITOG) AS TOTAL_ITOG,
         SUM(T.TOTAL_ITOG_DBT) AS TOTAL_ITOG_DBT,
         SUM(T.TOTAL_ITOG_KRD) AS TOTAL_ITOG_KRD
  FROM tt_prepare_report T
  GROUP BY T.REPORT_DATE,
           T.ID_COUNTRY,
           T.ID_TYPE_OPER;

END $$

SET GLOBAL event_scheduler = ON $$

DROP EVENT IF EXISTS CONSOLIDATION_REP_COMMON $$
CREATE EVENT CONSOLIDATION_REP_COMMON
ON SCHEDULE EVERY 1 MINUTE STARTS '2020-01-31 01:00:00'
ON COMPLETION NOT PRESERVE
ENABLE
COMMENT '' DO
BEGIN
  CALL work.CONSOLIDATION_REP_COMMON();
END $$
