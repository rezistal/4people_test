USE work;

ALTER TABLE work.users ADD CONSTRAINT FK_users_country FOREIGN KEY (ID_COUNTRY) REFERENCES work.countries (ID_COUNTRY) ON DELETE NO ACTION ON UPDATE NO ACTION;
ALTER TABLE work.users ADD CONSTRAINT FK_users_currency FOREIGN KEY (ID_CURRENCY) REFERENCES work.currencies (ID_CURRENCY) ON DELETE NO ACTION ON UPDATE NO ACTION;

CREATE INDEX IDX_operations_users ON work.operations (ID_USER);
ALTER TABLE work.operations ADD CONSTRAINT FK_operations_user FOREIGN KEY (ID_USER) REFERENCES work.users (ID_USER) ON DELETE NO ACTION ON UPDATE NO ACTION;

CREATE INDEX IDX_operations_type_opers ON work.operations (ID_TYPE_OPER);
ALTER TABLE work.operations ADD CONSTRAINT FK_operations_type_opers FOREIGN KEY (ID_TYPE_OPER) REFERENCES work.type_opers (ID_TYPE_OPER) ON DELETE NO ACTION ON UPDATE NO ACTION;

CREATE INDEX IDX_operations_dts ON work.operations (DT);

DROP TABLE IF EXISTS common_report_consolidation;
CREATE TABLE common_report_consolidation (
    REPORT_DATE DATE NOT NULL,
	ID_COUNTRY smallint(6) unsigned NOT NULL,
    ID_TYPE_OPER smallint(6) unsigned NOT NULL,
    TOTAL decimal(65,16) DEFAULT NULL,
    TOTAL_DBT decimal(65,16) DEFAULT NULL,
    TOTAL_KRD decimal(65,16) DEFAULT NULL,
    TOTAL_COMMISSION decimal(65,16) DEFAULT NULL,
    TOTAL_ITOG decimal(65,16) DEFAULT NULL,
    TOTAL_ITOG_DBT decimal(65,16) DEFAULT NULL,
    TOTAL_ITOG_KRD decimal(65,16) DEFAULT NULL,
    UNIQUE INDEX UIDX_common_report_consolidation (REPORT_DATE, ID_COUNTRY, ID_TYPE_OPER),
    CONSTRAINT FK_common_report_consolidation_country FOREIGN KEY (ID_COUNTRY) REFERENCES work.countries (ID_COUNTRY) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_common_report_consolidation_type_oper FOREIGN KEY (ID_TYPE_OPER) REFERENCES work.type_opers(ID_TYPE_OPER) ON DELETE NO ACTION ON UPDATE NO ACTION,
    INDEX IDX_common_report_consolidation_date (REPORT_DATE),
    INDEX IDX_common_report_consolidation_country (ID_COUNTRY),
    INDEX IDX_common_report_consolidation_type_oper (ID_TYPE_OPER)
)
ENGINE = INNODB;
