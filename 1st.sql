DELIMITER $$
USE work $$

DROP PROCEDURE IF EXISTS LOG_PARTITION_EVENT $$
CREATE PROCEDURE LOG_PARTITION_EVENT (
    IN iMODE VARCHAR(10)
)
LOG_PARTITION_EVENT:BEGIN
	
    DECLARE done INT DEFAULT 0;
    
	DECLARE vPOINT, vDT DATETIME;
    DECLARE vTITLE VARCHAR(32);
    
    DECLARE curdt CURSOR FOR
    SELECT TITLE, DT FROM tt_partition_intervals ORDER BY DT;
    DECLARE CONTINUE HANDLER FOR SQLSTATE '02000' SET done = 1;
    
    IF iMODE = 'create' THEN
        SET vPOINT = TIMESTAMP(CURRENT_DATE);
    ELSEIF iMODE = 'modify' THEN
        SET vPOINT = TIMESTAMP(CURRENT_DATE) + INTERVAL 5 DAY;
    END IF;

	DROP TEMPORARY TABLE IF EXISTS tt_partition_intervals;
	CREATE TEMPORARY TABLE tt_partition_intervals 
	(
        DT DATETIME,
        TITLE VARCHAR(32)
	);
    CREATE INDEX IDX_tt_partition_intervals ON tt_partition_intervals(TITLE);

	INSERT INTO tt_partition_intervals
	VALUES
    -- Храним последние 2 недели
	(@PNT:= vPOINT - INTERVAL 14 DAY, CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT)))),
	(@PNT:= @PNT + INTERVAL 1 DAY,    CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT)))),
	(@PNT:= @PNT + INTERVAL 1 DAY,    CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT)))),
	(@PNT:= @PNT + INTERVAL 1 DAY,    CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT)))),
	(@PNT:= @PNT + INTERVAL 1 DAY,    CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT)))),
	(@PNT:= @PNT + INTERVAL 1 DAY,    CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT)))),
	(@PNT:= @PNT + INTERVAL 1 DAY,    CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT)))),
	(@PNT:= @PNT + INTERVAL 1 DAY,    CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT)))),
	(@PNT:= @PNT + INTERVAL 1 DAY,    CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT)))),
	(@PNT:= @PNT + INTERVAL 1 DAY,    CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT)))),
	(@PNT:= @PNT + INTERVAL 1 DAY,    CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT)))),
	(@PNT:= @PNT + INTERVAL 1 DAY,    CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT)))),
	(@PNT:= @PNT + INTERVAL 1 DAY,    CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT)))),
	(@PNT:= @PNT + INTERVAL 1 DAY,    CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT)))),
    -- Текущая дата
	(@PNT:= @PNT + INTERVAL 1 DAY,    CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT)))),
    -- Запас 4 дня
	(@PNT:= @PNT + INTERVAL 1 DAY,    CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT)))),
	(@PNT:= @PNT + INTERVAL 1 DAY,    CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT)))),
	(@PNT:= @PNT + INTERVAL 1 DAY,    CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT)))),
	(@PNT:= @PNT + INTERVAL 1 DAY,    CONCAT('P', FLOOR(UNIX_TIMESTAMP(@PNT))));

    IF iMODE = 'create' THEN
    
      SET @SQL_PARTITION = '';
      
	  OPEN curdt;
      SET done = 0;
      FETCH curdt INTO vTITLE, vDT;
	  WHILE done = 0 DO
          
          SET @SQL_PARTITION = CONCAT(@SQL_PARTITION,
                                      '\nPARTITION ', vTITLE, ' VALUES LESS THAN (UNIX_TIMESTAMP("', vDT, '")),');
      
	  	
          SET done = 0;
	  	FETCH curdt INTO vTITLE, vDT;
      
	  END WHILE;
	  CLOSE curdt;
      
      SET @SQL_PARTITION = CONCAT('
          CREATE TABLE log_check_user (
            dt timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            idUser int(11) DEFAULT NULL,
            idAction int(11) DEFAULT NULL,
            IncomingParams json DEFAULT NULL,
            OtherParams json DEFAULT NULL,
            Message smallint(6) DEFAULT NULL
          )
          ENGINE = InnoDB
          PARTITION BY RANGE ( UNIX_TIMESTAMP(dt) ) (',
          TRIM(TRAILING ',' FROM @SQL_PARTITION),'
          -- PARTITION FFF VALUES LESS THAN (MAXVALUE)
          );'
      );
      
      DROP TABLE IF EXISTS log_check_user;
      PREPARE STMT FROM @SQL_PARTITION;
      EXECUTE STMT;
      DEALLOCATE PREPARE STMT;
      
    ELSEIF iMODE = 'modify' THEN
    
      SELECT GROUP_CONCAT(CONCAT('PARTITION ', T.TITLE, ' VALUES LESS THAN ( UNIX_TIMESTAMP("', T.DT, '"))'))
      INTO @CREATE_PARTITIONS
      FROM tt_partition_intervals             T
      LEFT JOIN information_schema.partitions P ON  T.TITLE = P.PARTITION_NAME
                                                AND P.TABLE_NAME = 'log_check_user'
                                                AND P.TABLE_SCHEMA = 'work'
      WHERE TRUE
        AND P.PARTITION_NAME IS NULL;
        
      IF @CREATE_PARTITIONS IS NOT NULL THEN
          SET @SQLS_CREATE = CONCAT('ALTER TABLE log_check_user ADD PARTITION (', @CREATE_PARTITIONS, ' )');
          PREPARE STMT FROM @SQLS_CREATE;
          EXECUTE STMT;
          DEALLOCATE PREPARE STMT;
      ELSE
          SELECT 'AREADY MODIFIED' AS RES;
      END IF;

      SELECT GROUP_CONCAT(P.PARTITION_NAME) AS NAMES
      INTO @DROP_PARTITIONS
      FROM information_schema.partitions P
      LEFT JOIN tt_partition_intervals   T ON  T.TITLE = P.PARTITION_NAME
      WHERE TRUE
        AND P.TABLE_NAME = 'log_check_user'
        AND P.TABLE_SCHEMA = 'work'
        AND P.PARTITION_NAME <> 'FFF'
        AND T.TITLE IS NULL;
      
      IF @DROP_PARTITIONS IS NOT NULL THEN
          SET @SQLS_DROP = CONCAT('ALTER TABLE log_check_user DROP PARTITION ', @DROP_PARTITIONS);
          PREPARE STMT FROM @SQLS_DROP;
          EXECUTE STMT;
          DEALLOCATE PREPARE STMT;
      ELSE
          SELECT 'AREADY MODIFIED' AS RES;
      END IF;
      
    END IF;
END $$

CALL log_partition_event('create') $$
CALL log_partition_event('modify') $$
