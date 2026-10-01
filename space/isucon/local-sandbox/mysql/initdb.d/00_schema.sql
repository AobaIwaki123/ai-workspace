-- ==========================================
-- ISUCON 模擬環境 初期スキーマ & データ
-- ==========================================

DROP TABLE IF EXISTS comments;
DROP TABLE IF EXISTS posts;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE posts (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'published',
    view_count INT NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    -- 意図的に status, created_at, user_id に INDEX を貼っていません
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE comments (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    post_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    body TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    -- 意図的に post_id に INDEX を貼っていません (N+1時に激重になる)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 初期データ生成
DELIMITER //
CREATE PROCEDURE InsertSampleData()
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE u_id BIGINT;
    DECLARE p_id BIGINT;

    -- 100 ユーザー作成
    WHILE i <= 100 DO
        INSERT INTO users (name, email) VALUES (CONCAT('User_', i), CONCAT('user_', i, '@example.com'));
        SET i = i + 1;
    END WHILE;

    -- 1000 投稿作成
    SET i = 1;
    WHILE i <= 1000 DO
        SET u_id = 1 + (i % 100);
        INSERT INTO posts (user_id, title, content, status, view_count, created_at)
        VALUES (u_id, CONCAT('Title ', i), CONCAT('This is content for post number ', i), IF(i % 5 = 0, 'draft', 'published'), i * 7, DATE_SUB(NOW(), INTERVAL i MINUTE));
        SET i = i + 1;
    END WHILE;

    -- 3000 コメント作成
    SET i = 1;
    WHILE i <= 3000 DO
        SET p_id = 1 + (i % 1000);
        SET u_id = 1 + (i % 100);
        INSERT INTO comments (post_id, user_id, body)
        VALUES (p_id, u_id, CONCAT('Comment body for comment ', i));
        SET i = i + 1;
    END WHILE;
END //
DELIMITER ;

CALL InsertSampleData();
DROP PROCEDURE InsertSampleData;
