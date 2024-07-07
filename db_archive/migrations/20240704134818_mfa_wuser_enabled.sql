-- migrate:up

ALTER TABLE wuser
ADD COLUMN mfa_enabled BOOL NOT NULL DEFAULT false;

-- migrate:down

ALTER TABLE wuser
DROP COLUMN mfa_enabled;
