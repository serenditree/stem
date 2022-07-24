SET @VERSION = '0.0.1'
;
-- ---------------------------------------------------------------------------------------------------------------------
-- META
-- ---------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS Meta
(
    meta     VARCHAR(64) NOT NULL,
    value    VARCHAR(64) NOT NULL,
    created  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT meta
        UNIQUE (meta)
)
    CHARACTER SET 'utf8'
    ENGINE = InnoDB
;

INSERT INTO Meta (meta, value)
VALUES ('version', @VERSION)
ON DUPLICATE KEY UPDATE value    = @VERSION,
                        modified = CURRENT_TIMESTAMP
;

SELECT *
FROM Meta
;
-- ---------------------------------------------------------------------------------------------------------------------
-- USER
-- ---------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS User
(
    id       BIGINT PRIMARY KEY AUTO_INCREMENT,
    email    VARCHAR(64)  NULL,
    password VARCHAR(128) NOT NULL,
    username VARCHAR(32)  NOT NULL,
    created  DATETIME     NOT NULL,
    modified DATETIME     NOT NULL,
    CONSTRAINT email
        UNIQUE (email),
    CONSTRAINT username
        UNIQUE (username)
)
    CHARACTER SET 'utf8'
    ENGINE = InnoDB
;

SELECT *
FROM User
LIMIT 5
;
-- ---------------------------------------------------------------------------------------------------------------------
-- ROLE
-- ---------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS Role
(
    userId   BIGINT      NOT NULL,
    roleType VARCHAR(16) NOT NULL,
    PRIMARY KEY (userId, roleType),
    CONSTRAINT fkUserId
        FOREIGN KEY (userId) REFERENCES User (id)
            ON DELETE CASCADE
)
    CHARACTER SET 'utf8'
    ENGINE = InnoDB
;
-- ---------------------------------------------------------------------------------------------------------------------
-- POLL
-- ---------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS Poll
(
    id       BIGINT PRIMARY KEY AUTO_INCREMENT,
    title    VARCHAR(64) NOT NULL,
    userId   BIGINT      NOT NULL,
    seedId   VARCHAR(36) NOT NULL,
    created  DATETIME    NOT NULL,
    modified DATETIME    NOT NULL,
    INDEX (seedId)
)
    CHARACTER SET 'utf8'
    ENGINE = InnoDB
;
-- ---------------------------------------------------------------------------------------------------------------------
-- POLL OPTION
-- ---------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PollOption
(
    id     BIGINT PRIMARY KEY AUTO_INCREMENT,
    text   VARCHAR(32) NOT NULL,
    votes  INT         NULL,
    pollId BIGINT      NOT NULL,
    CONSTRAINT fkPollId
        FOREIGN KEY (pollId) REFERENCES Poll (id)
            ON DELETE CASCADE
)
    CHARACTER SET 'utf8'
    ENGINE = InnoDB
;
-- ---------------------------------------------------------------------------------------------------------------------
-- FENCE RECORD
-- ---------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS FenceRecord
(
    _id        BINARY(16) PRIMARY KEY,
    action     VARCHAR(16) NOT NULL,
    userId     VARCHAR(36) NOT NULL,
    entityId   VARCHAR(36) NULL, -- For cascade remove.
    expiration DATETIME    NULL,
    INDEX (action),
    INDEX (userId),
    INDEX (entityId),
    INDEX (expiration)
)
    CHARACTER SET 'utf8'
    ENGINE = InnoDB
;
-- ---------------------------------------------------------------------------------------------------------------------
-- FENCE ID RECORD
-- ---------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS FenceIdRecord
(
    subject VARCHAR(1024) PRIMARY KEY
)
    CHARACTER SET 'utf8'
    ENGINE = InnoDB
;
