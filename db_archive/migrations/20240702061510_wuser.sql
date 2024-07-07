-- migrate:up

CREATE EXTENSION citext;

CREATE TABLE wuser (
    id UUID PRIMARY KEY,
    provider_id CITEXT NOT NULL,
    provider TEXT NOT NULL,
    password_hash TEXT,
    email_verified BOOL NOT NULL DEFAULT false,
    last_login TIMESTAMPTZ,
    locked_until TIMESTAMPTZ
);

CREATE UNIQUE INDEX UX_wuser_provider_id
ON wuser (provider_id, provider);

-- migrate:down

DROP TABLE wuser;

DROP EXTENSION citext;
