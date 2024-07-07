-- migrate:up

CREATE TABLE wuser_session (
    id UUID PRIMARY KEY,
    verification_hash BYTEA NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    wuser_id UUID NOT NULL
        REFERENCES wuser (id)
);

CREATE INDEX IX_wuser_session_wuser
ON wuser_session (wuser_id);

-- migrate:down

DROP TABLE wuser_session;
