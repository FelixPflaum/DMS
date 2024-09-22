export const creationSqlQueries: string[] = [
    `CREATE TABLE settings (
        skey VARCHAR(20) NOT NULL,
        svalue TEXT NOT NULL,
        PRIMARY KEY (skey)
	);`,
    `CREATE TABLE users (
        loginId VARCHAR(18) NOT NULL,
        loginToken VARCHAR(32) DEFAULT '',
        userName VARCHAR(32) DEFAULT '',
        validUntil BIGINT UNSIGNED DEFAULT 0,
        permissions INT UNSIGNED DEFAULT 0,
        lastActivity BIGINT DEFAULT 0,
        PRIMARY KEY (loginId)
	);`,
    `CREATE TABLE audit (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        timestamp BIGINT NOT NULL,
        loginId VARCHAR(18) NOT NULL,
        userName VARCHAR(32) NOT NULL,
        eventInfo VARCHAR(255) NOT NULL,
        PRIMARY KEY (id)
	);`,
    `CREATE TABLE players (
        playerName VARCHAR(20) NOT NULL,
        classId TINYINT UNSIGNED NOT NULL,
        points INT NOT NULL DEFAULT 0,
        account VARCHAR(18),
        PRIMARY KEY (playerName),
        FOREIGN KEY (account) REFERENCES users(loginId) ON DELETE SET NULL ON UPDATE CASCADE
	);`,
    `CREATE TABLE pointHistory (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        timestamp BIGINT NOT NULL,
        playerName VARCHAR(20) NOT NULL,
        pointChange INT NOT NULL,
        newPoints INT NOT NULL,
        changeType VARCHAR(20) NOT NULL,
        reason VARCHAR(100),
        PRIMARY KEY (id),
        UNIQE KEY (timestamp, playerName),
        KEY (changeType),
        FOREIGN KEY (playerName) REFERENCES players(playerName) ON DELETE CASCADE ON UPDATE CASCADE
	);`,
    `CREATE TABLE lootHistory (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        guid VARCHAR(32) NOT NULL,
        timestamp BIGINT NOT NULL,
        playerName VARCHAR(20) NOT NULL,
        itemId INT UNSIGNED NOT NULL,
        response VARCHAR(32) NOT NULL,
        reverted TINYINT(1) NOT NULL,
        PRIMARY KEY (id),
        KEY (timestamp),
        UNIQUE KEY (guid),
        FOREIGN KEY (playerName) REFERENCES players(playerName) ON DELETE CASCADE ON UPDATE CASCADE
	);`,
    `CREATE TABLE itemData (
        itemId INT UNSIGNED NOT NULL,
        itemName VARCHAR(100) NOT NULL,
        qualityId TINYINT NOT NULL,
        iconId INT UNSIGNED NOT NULL,
        PRIMARY KEY (itemId),
        KEY (name),
        KEY (quality)
	);`,
];
