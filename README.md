# Wisp auth example

```shell
docker-compose up -d
echo 'DATABASE_URL="postgres://postgres:postgres@127.0.0.1:5432/wisp_auth_example?sslmode=disable"' > .env
dbmate migrate
gleam run
```