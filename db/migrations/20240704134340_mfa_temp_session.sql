-- migrate:up

CREATE TABLE mfa_temp_session (
    id UUID PRIMARY KEY,
    verification_hash BYTEA NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    wuser_id UUID NOT NULL
        REFERENCES wuser (id),
    verification_code TEXT NOT NULL
);

-- migrate:down

DROP TABLE mfa_temp_session;
