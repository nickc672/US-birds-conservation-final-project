-- Shared text cleanup used by the parsing steps.
-- Trim whitespace from both ends of a string, including the non-breaking spaces in Wikipedia text.
DROP FUNCTION IF EXISTS ws_trim;
CREATE FUNCTION ws_trim(s TEXT) RETURNS TEXT
    DETERMINISTIC NO SQL
    RETURN REGEXP_REPLACE(s, '^[\\s\\p{Z}\\x{0B}\\x{1C}-\\x{1F}\\x{85}]+|[\\s\\p{Z}\\x{0B}\\x{1C}-\\x{1F}\\x{85}]+$', '');
