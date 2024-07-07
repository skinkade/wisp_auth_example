-- migrate:up

CREATE TABLE email_registration (
    id UUID PRIMARY KEY,
    verification_hash BYTEA NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    sent_to CITEXT NOT NULL
);


-- migrate:down

DROP TABLE email_registration;
