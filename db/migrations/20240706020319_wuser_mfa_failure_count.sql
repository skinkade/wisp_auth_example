-- migrate:up

ALTER TABLE wuser
ADD COLUMN failed_mfa_count SMALLINT NOT NULL DEFAULT 0;

UPDATE wuser
SET failed_login_count = 0
WHERE failed_login_count IS NULL;

ALTER TABLE wuser
ALTER COLUMN failed_login_count SET DEFAULT 0,
ALTER COLUMN failed_login_count TYPE INT,
ALTER COLUMN failed_login_count SET NOT NULL;

-- migrate:down

ALTER TABLE wuser
DROP COLUMN failed_mfa_count;

ALTER TABLE wuser
ALTER COLUMN failed_login_count SET DEFAULT 0,
ALTER COLUMN failed_login_count TYPE SMALLINT,
ALTER COLUMN failed_login_count SET NOT NULL;
