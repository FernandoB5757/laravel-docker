-- ============================================================
-- MariaDB Init Script
-- Creates databases for each project automatically on first run
-- Add additional databases here as needed
-- ============================================================

-- Project databases
-- CREATE DATABASE IF NOT EXISTS `project1` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- CREATE DATABASE IF NOT EXISTS `project2` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Grant permissions to the laravel user on all databases
-- GRANT ALL PRIVILEGES ON `project1`.* TO 'laravel'@'%';
-- GRANT ALL PRIVILEGES ON `project2`.* TO 'laravel'@'%';

-- Grant wildcard for new databases matching pattern
-- GRANT ALL PRIVILEGES ON `laravel_%`.* TO 'laravel'@'%';

-- Read-only user for MariaDB MCP server (used by Claude Code)
CREATE USER IF NOT EXISTS 'mcp_readonly'@'%' IDENTIFIED BY 'mcp_readonly';
GRANT SELECT, SHOW DATABASES ON *.* TO 'mcp_readonly'@'%';

FLUSH PRIVILEGES;
