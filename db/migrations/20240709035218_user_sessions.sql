-- migrate:up

CREATE TABLE user_sessions (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    session_hash BYTEA NOT NULL,
    user_id UUID NOT NULL
        REFERENCES users (id),
    created_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE UNIQUE INDEX UX_session_hash
ON user_sessions (session_hash);

CREATE INDEX IX_session_user
ON user_sessions (user_id);

-- migrate:down

DROP TABLE user_sessions;
