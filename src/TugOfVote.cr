require "kemal"
require "dotenv"
require "db"
require "sqlite3"
require "dotenv"
require "logger"
require "io"

require "./Models"
require "./Helpers"
require "./Webhooks"
require "./views/main"
require "./views/cap"
require "./views/new"

Dotenv.load!

BASE_URL = ENV["BASE_URL"]

LOG = Logger.new(
  IO::MultiWriter.new(File.new(ENV["LOG_FILE"], "a"), STDOUT),
  level = ENV["KEMAL_ENV"] == "production" ? Logger::Severity::INFO : Logger::Severity::DEBUG
)

LOG.info "Initializing."

DATABASE = DB.open "sqlite3:./tugofvote.db"
DATABASE.exec "PRAGMA foreign_keys = ON"

Kemal.config.logger = ToVLogger.new
Kemal.run ENV["PORT"].to_i
