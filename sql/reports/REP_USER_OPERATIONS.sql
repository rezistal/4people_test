DELIMITER $$
USE work $$

DROP PROCEDURE IF EXISTS REP_USER_OPERATIONS $$
CREATE PROCEDURE REP_USER_OPERATIONS
(
  IN iID_USER INT,
  IN iDATETIME_FROM DATETIME,
  IN iDATETIME_TO DATETIME
)
REP_USER_OPERATIONS:BEGIN

  DROP TEMPORARY TABLE IF EXISTS tt_report;
  CREATE TEMPORARY TABLE tt_report AS
  SELECT O.ID_USER,
         O.ID_TYPE_OPER,
         OT.NAME_OPER,
         -- В рублях
         SUM(O.AMOUNT_OPER * IFNULL(CR.BASE_RATE, 0)) AS RUB_TOTAL, -- обороты суммарно
         SUM(IF(O.MOVE = -1, O.AMOUNT_OPER * IFNULL(CR.BASE_RATE, 0), NULL)) AS RUB_TOTAL_DBT, -- дебет
         SUM(IF(O.MOVE =  1, O.AMOUNT_OPER * IFNULL(CR.BASE_RATE, 0), NULL)) AS RUB_TOTAL_KRD, -- кредит
         SUM(O.AMOUNT_OPER * IFNULL(OT.COMISSION, 0) * IFNULL(CR.BASE_RATE, 0) / 100) AS RUB_TOTAL_COMMISSION,
         SUM(O.AMOUNT_OPER  * (100.00 - IFNULL(OT.COMISSION, 0)) * IFNULL(CR.BASE_RATE, 0) / 100) AS RUB_TOTAL_ITOG,  -- обороты пользователей суммарно
         SUM(IF(O.MOVE = -1, O.AMOUNT_OPER  * (100.00 - IFNULL(OT.COMISSION, 0)) * IFNULL(CR.BASE_RATE, 0) / 100, NULL)) AS RUB_TOTAL_ITOG_DBT, -- дебет пользователей
         SUM(IF(O.MOVE =  1, O.AMOUNT_OPER  * (100.00 - IFNULL(OT.COMISSION, 0)) * IFNULL(CR.BASE_RATE, 0) / 100, NULL)) AS RUB_TOTAL_ITOG_KRD, -- кредит пользователей
         -- В валюте пользователя
         SUM(O.AMOUNT_OPER) AS TOTAL, -- обороты суммарно
         SUM(IF(O.MOVE = -1, O.AMOUNT_OPER, NULL)) AS TOTAL_DBT, -- дебет
         SUM(IF(O.MOVE =  1, O.AMOUNT_OPER, NULL)) AS TOTAL_KRD, -- кредит
         SUM(O.AMOUNT_OPER * IFNULL(OT.COMISSION, 0) / 100) AS TOTAL_COMMISSION,
         SUM(O.AMOUNT_OPER  * (100.00 - IFNULL(OT.COMISSION, 0)) / 100) AS TOTAL_ITOG,  -- обороты пользователей суммарно
         SUM(IF(O.MOVE = -1, O.AMOUNT_OPER  * (100.00 - IFNULL(OT.COMISSION, 0)) / 100, NULL)) AS TOTAL_ITOG_DBT, -- дебет пользователей
         SUM(IF(O.MOVE =  1, O.AMOUNT_OPER  * (100.00 - IFNULL(OT.COMISSION, 0)) / 100, NULL)) AS TOTAL_ITOG_KRD -- кредит пользователей
  FROM work.operations   O
  JOIN work.users        U ON U.ID_USER = O.ID_USER
  JOIN work.type_opers  OT ON OT.ID_TYPE_OPER = O.ID_TYPE_OPER
  JOIN work.currencies  CR ON CR.ID_CURRENCY = U.ID_CURRENCY
  WHERE O.DT BETWEEN iDATETIME_FROM AND iDATETIME_TO
    AND O.ID_USER = iID_USER
  GROUP BY O.ID_TYPE_OPER WITH ROLLUP;

  SELECT 'User ID',
         'Operation type',
         'Turnover',
         'Turnover debt',
         'Turnover credit',
         'Comission',
         'User Turnover',
         'User Turnover debt',
         'User Turnover credit',
         'Rubles Turnover',
         'Rubles Turnover debt',
         'Rubles Turnover credit',
         'Rubles Comission',
         'Rubles User Turnover',
         'Rubles User Turnover debt',
         'Rubles User Turnover credit'
  UNION ALL
  SELECT T.ID_USER,
         T.NAME_OPER,
         TRUNCATE(T.TOTAL, 5) AS TOTAL,
         TRUNCATE(T.TOTAL_DBT, 5) AS TOTAL_DBT,
         TRUNCATE(T.TOTAL_KRD, 5) AS TOTAL_KRD,
         TRUNCATE(T.TOTAL_COMMISSION, 5) AS TOTAL_COMMISSION,
         TRUNCATE(T.TOTAL_ITOG, 5) AS TOTAL_ITOG,
         TRUNCATE(T.TOTAL_ITOG_DBT, 5) AS TOTAL_ITOG_DBT,
         TRUNCATE(T.TOTAL_ITOG_KRD, 5) AS TOTAL_ITOG_KRD,
         TRUNCATE(T.RUB_TOTAL, 5) AS RUB_TOTAL,
         TRUNCATE(T.RUB_TOTAL_DBT, 5) AS RUB_TOTAL_DBT,
         TRUNCATE(T.RUB_TOTAL_KRD, 5) AS RUB_TOTAL_KRD,
         TRUNCATE(T.RUB_TOTAL_COMMISSION, 5) AS RUB_TOTAL_COMMISSION,
         TRUNCATE(T.RUB_TOTAL_ITOG, 5) AS RUB_TOTAL_ITOG,
         TRUNCATE(T.RUB_TOTAL_ITOG_DBT, 5) AS RUB_TOTAL_ITOG_DBT,
         TRUNCATE(T.RUB_TOTAL_ITOG_KRD, 5) AS RUB_TOTAL_ITOG_KRD
  FROM tt_report T;

END $$

-- CALL REP_USER_OPERATIONS(
-- 1,
-- '2019-06-01 14:00:00',
-- '2019-06-05 14:00:00'
-- ) $$

