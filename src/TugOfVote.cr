require "kemal"
require "dotenv"
require "db"
require "sqlite3"
require "dotenv"
require "log"
require "io"

require "./Models"
require "./Helpers"
require "./Webhooks"
require "./views/main"
require "./views/cap"
require "./views/new"

Dotenv.load ".env"

case ENV["ENVIRONMENT"]?
when "production"
  logging false
when "development"
  logging true
else
  raise "Invalid ENVIRONMENT env variable: should be 'development' or 'production'"
end

Log.info &.emit("Initializing.")

DATABASE = DB.open "sqlite3:" + ENV["DATABASE_PATH"]
DATABASE.exec "PRAGMA foreign_keys = ON"

after_all do |ctx|
  ctx.response.headers.add("Content-Type", "text/html; charset=utf-8")
end

Kemal.run ENV["PORT"].to_i
