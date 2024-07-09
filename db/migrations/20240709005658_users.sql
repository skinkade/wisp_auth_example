-- migrate:up

CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE users (
    id UUID PRIMARY KEY,
    email citext NOT NULL,
    email_verified_at TIMESTAMPTZ,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    disabled_at TIMESTAMPTZ,
    last_login TIMESTAMPTZ,
    login_failures INT NOT NULL DEFAULT 0,
    locked_until TIMESTAMPTZ
);

CREATE UNIQUE INDEX UX_user_email
ON users (email);

-- migrate:down

DROP TABLE users;
