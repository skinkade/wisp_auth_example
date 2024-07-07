-- migrate:up

ALTER TABLE wuser
ADD COLUMN failed_login_count SMALLINT;

-- migrate:down

ALTER TABLE wuser
DROP COLUMN failed_login_count;
