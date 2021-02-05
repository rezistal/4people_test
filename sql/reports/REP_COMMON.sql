DELIMITER $$
USE work $$

DROP PROCEDURE IF EXISTS REP_COMMON $$
CREATE PROCEDURE REP_COMMON
(
  IN iDATETIME_FROM DATETIME,
  IN iDATETIME_TO DATETIME
)
REP_COMMON:BEGIN

  DECLARE done INT DEFAULT 0;
  DECLARE vDATE_FROM, vDATE_TO DATE;
  DECLARE vOPERATIONS_IN_PACK,vCURRENT_PACK INT;

  DECLARE curpack CURSOR FOR SELECT T.PACK_NUM FROM tt_operations_packs T GROUP BY T.PACK_NUM ORDER BY T.PACK_NUM;
  DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;

  SET vDATE_FROM = CAST(iDATETIME_FROM AS DATE);
  SET vDATE_FROM = IF(vDATE_FROM = iDATETIME_FROM, vDATE_FROM, vDATE_FROM + INTERVAL 1 DAY);

  SET vDATE_TO = CAST(iDATETIME_TO AS DATE);
  SET vDATE_TO = IF(vDATE_TO = iDATETIME_TO, vDATE_TO, vDATE_TO - INTERVAL 1 DAY);

  SET vOPERATIONS_IN_PACK = 100;

  DROP TEMPORARY TABLE IF EXISTS tt_operations_packs;
  CREATE TEMPORARY TABLE tt_operations_packs
  (
    ID_NUM INT NOT NULL AUTO_INCREMENT,
    PACK_NUM INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY(`ID_NUM`)
  )
  SELECT O.ID_OPERATION,
         O.ID_USER,
         O.ID_TYPE_OPER,
         O.MOVE,
         O.AMOUNT_OPER
  FROM work.operations O
  WHERE O.DT BETWEEN iDATETIME_FROM AND vDATE_FROM
     OR O.DT BETWEEN vDATE_TO + INTERVAL 1 DAY AND iDATETIME_TO
     ;
  CREATE INDEX idx_tt_operations_packs ON tt_operations_packs(PACK_NUM);
  CREATE INDEX idx_tt_operations_packs_type_oper ON tt_operations_packs(ID_TYPE_OPER);
  CREATE INDEX idx_tt_operations_packs_user ON tt_operations_packs(ID_USER);

  UPDATE tt_operations_packs
  SET PACK_NUM = (ID_NUM DIV vOPERATIONS_IN_PACK) + 1;

  DROP TEMPORARY TABLE IF EXISTS tt_prepare_report;
  CREATE TEMPORARY TABLE tt_prepare_report
  (
    NAME_COUNTRY varchar(50) DEFAULT '',
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
    SELECT C.ID_COUNTRY,
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
    GROUP BY C.ID_COUNTRY, OT.ID_TYPE_OPER
    ;

    INSERT INTO tt_prepare_report
    (
      NAME_COUNTRY,
      NAME_OPER,
      TOTAL,
      TOTAL_DBT,
      TOTAL_KRD,
      TOTAL_COMMISSION,
      TOTAL_ITOG,
      TOTAL_ITOG_DBT,
      TOTAL_ITOG_KRD
    )
    SELECT NAME_COUNTRY,
           NAME_OPER,
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

  INSERT INTO tt_prepare_report
  SELECT C.NAME_COUNTRY,
         OT.NAME_OPER,
         CRC.TOTAL,
         CRC.TOTAL_DBT,
         CRC.TOTAL_KRD,
         CRC.TOTAL_COMMISSION,
         CRC.TOTAL_ITOG,
         CRC.TOTAL_ITOG_DBT,
         CRC.TOTAL_ITOG_KRD
  FROM work.common_report_consolidation CRC
  JOIN work.countries       C ON C.ID_COUNTRY = CRC.ID_COUNTRY
  JOIN work.type_opers     OT ON OT.ID_TYPE_OPER = CRC.ID_TYPE_OPER
  WHERE CRC.REPORT_DATE BETWEEN vDATE_FROM AND vDATE_TO;

  DROP TEMPORARY TABLE IF EXISTS tt_report;
  CREATE TEMPORARY TABLE tt_report AS
  SELECT IF(T.NAME_COUNTRY IS NULL,
            'Total for all countries:',
             IF(T.NAME_OPER IS NULL,
                CONCAT('Total for country ', T.NAME_COUNTRY, ':'),
                T.NAME_COUNTRY
                )
            ) AS NAME_COUNTRY,
         T.NAME_OPER,
         SUM(T.TOTAL) AS TOTAL,
         SUM(T.TOTAL_DBT) AS TOTAL_DBT,
         SUM(T.TOTAL_KRD) AS TOTAL_KRD,
         SUM(T.TOTAL_COMMISSION) AS TOTAL_COMMISSION,
         SUM(T.TOTAL_ITOG) AS TOTAL_ITOG,
         SUM(T.TOTAL_ITOG_DBT) AS TOTAL_ITOG_DBT,
         SUM(T.TOTAL_ITOG_KRD) AS TOTAL_ITOG_KRD
  FROM tt_prepare_report T
  GROUP BY T.NAME_COUNTRY, T.NAME_OPER WITH ROLLUP;

  SELECT 'Country',
         'Operation type',
         'Turnover',
         'Turnover debt',
         'Turnover credit',
         'Comission',
         'Users Turnover',
         'Users Turnover debt',
         'Users Turnover credit'
  UNION ALL
  SELECT T.NAME_COUNTRY,
         T.NAME_OPER,
         TRUNCATE(T.TOTAL, 5) AS TOTAL,
         TRUNCATE(T.TOTAL_DBT, 5) AS TOTAL_DBT,
         TRUNCATE(T.TOTAL_KRD, 5) AS TOTAL_KRD,
         TRUNCATE(T.TOTAL_COMMISSION, 5) AS TOTAL_COMMISSION,
         TRUNCATE(T.TOTAL_ITOG, 5) AS TOTAL_ITOG,
         TRUNCATE(T.TOTAL_ITOG_DBT, 5) AS TOTAL_ITOG_DBT,
         TRUNCATE(T.TOTAL_ITOG_KRD, 5) AS TOTAL_ITOG_KRD
  FROM tt_report T;

END $$

-- CALL REP_COMMON(
-- '2019-06-01 14:00:00',
-- '2019-06-05 14:00:00'
-- ) $$

