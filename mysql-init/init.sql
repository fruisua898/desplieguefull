DROP DATABASE IF EXISTS critical_blunder;
CREATE DATABASE critical_blunder;
USE critical_blunder;

-- Tabla de usuarios
CREATE TABLE IF NOT EXISTS user (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('PLAYER', 'GAME_MASTER', 'ADMIN') DEFAULT 'PLAYER'
);

-- Tabla de campañas
CREATE TABLE IF NOT EXISTS campaign (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description VARCHAR(500) NOT NULL,
    status ENUM('ACTIVE', 'FINISHED', 'PAUSED') DEFAULT 'ACTIVE',
    gamemaster_id BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (gamemaster_id) REFERENCES user(id) ON DELETE CASCADE
);


-- Tabla de personajes
CREATE TABLE IF NOT EXISTS hero (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    user_id BIGINT NOT NULL,
    description VARCHAR(1000),
    age INT,
    appearance VARCHAR(255),	
    hero_class ENUM('BARBARIAN','BARD','CLERIC','DRUID','FIGHTER','MONK','PALADIN','RANGER','ROGUE','SORCERER','WARLOCK','WIZARD') DEFAULT 'BARBARIAN',
    FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE
);

-- Relación de personajes y campañas (muchos a muchos)
CREATE TABLE IF NOT EXISTS hero_campaign (
    hero_id BIGINT NOT NULL,
    campaign_id BIGINT NOT NULL,
    level INT DEFAULT 1,
    experience INT DEFAULT 0,
    status ENUM('ALIVE', 'DEAD', 'RETIRED') DEFAULT 'ALIVE',
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (hero_id, campaign_id),
    FOREIGN KEY (hero_id) REFERENCES `hero`(id) ON DELETE CASCADE,
    FOREIGN KEY (campaign_id) REFERENCES campaign(id) ON DELETE CASCADE
);

-- Tabla de eventos
CREATE TABLE IF NOT EXISTS event (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    campaign_id BIGINT NOT NULL,
    title VARCHAR(255) NOT NULL,
    description VARCHAR(1000),
    event_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (campaign_id) REFERENCES campaign(id) ON DELETE CASCADE
);

-- Notas de campaña
CREATE TABLE IF NOT EXISTS campaign_note (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    campaign_id BIGINT NOT NULL,
    title VARCHAR(255) NOT NULL,
    content VARCHAR(1000),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    author VARCHAR(100) NOT NULL,
    FOREIGN KEY (campaign_id) REFERENCES campaign(id) ON DELETE CASCADE
);

-- Historial de heroes
CREATE TABLE IF NOT EXISTS hero_history (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    hero_id BIGINT NOT NULL,
    campaign_id BIGINT NOT NULL,
    level INT,
    experience INT,
    status ENUM('ALIVE', 'DEAD', 'RETIRED') DEFAULT 'ALIVE',
    left_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (hero_id) REFERENCES hero(id) ON DELETE CASCADE,
    FOREIGN KEY (campaign_id) REFERENCES campaign(id) ON DELETE CASCADE
);

DELIMITER //

CREATE TRIGGER after_hero_campaign_delete
AFTER DELETE ON hero_campaign
FOR EACH ROW
BEGIN
    INSERT INTO hero_history (hero_id, campaign_id, level, experience, status, left_at)
    VALUES (OLD.hero_id, OLD.campaign_id, OLD.level, OLD.experience, OLD.status, NOW());
END //

DELIMITER ;

DELIMITER //

CREATE TRIGGER after_hero_campaign_update
AFTER UPDATE ON hero_campaign
FOR EACH ROW
BEGIN
    IF NEW.status = 'RETIRED' OR NEW.status = 'DEAD' THEN
        INSERT INTO hero_history (hero_id, campaign_id, level, experience, status, left_at)
        VALUES (NEW.hero_id, NEW.campaign_id, NEW.level, NEW.experience, NEW.status, NOW());
    END IF;
END //

DELIMITER ;

ALTER TABLE hero_history
ADD CONSTRAINT fk_hero_history_hero
FOREIGN KEY (hero_id)
REFERENCES hero(id)
ON DELETE CASCADE;

DELIMITER //

CREATE TRIGGER before_insert_hero_campaign_restore
BEFORE INSERT ON hero_campaign
FOR EACH ROW
BEGIN
    DECLARE history_count INT;
    DECLARE last_level INT;
    DECLARE last_experience INT;
    DECLARE last_status ENUM('ALIVE', 'DEAD', 'RETIRED');

    -- Contar cuántas entradas hay en el historial
    SELECT COUNT(*) INTO history_count
    FROM hero_history
    WHERE hero_id = NEW.hero_id AND campaign_id = NEW.campaign_id;

    -- Si hay historial, obtenemos el registro más reciente
    IF history_count > 0 THEN
        SELECT level, experience, status
        INTO last_level, last_experience, last_status
        FROM hero_history
        WHERE hero_id = NEW.hero_id AND campaign_id = NEW.campaign_id
        ORDER BY left_at DESC
        LIMIT 1;

        -- Restaurar valores del último registro
        SET NEW.level = last_level;
        SET NEW.experience = last_experience;
        SET NEW.status = 'ALIVE';
    ELSE
        SET NEW.level = 1;
        SET NEW.experience = 0;
        SET NEW.status = 'ALIVE';
    END IF;
END //

DELIMITER ;