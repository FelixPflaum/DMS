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
        PRIMARY KEY (loginId)
	);`,
    `CREATE TABLE audit (
        id INT UNSIGNED NOT NULL AUTO_INCREMENT,
        timestamp TIMESTAMP NOT NULL,
        loginId VARCHAR(18) NOT NULL,
        userName VARCHAR(32) NOT NULL,
        eventInfo VARCHAR(255) NOT NULL,
        PRIMARY KEY (id)
	);`,
];
