require "kemal"
require "dotenv"
require "db"
require "sqlite3"
require "dotenv"

require "./ViewMain"
require "./ViewCap"
require "./ViewNew"
require "./ViewCapActions"

Dotenv.load!

error 404 do
  error_text = "This URL is unknown, invalid or has been revoked. Sorry."
  render "src/ecr/cap_invalid.ecr"
end

error 500 do
  error_text = "Internal server error. Please try again or contact the admin."
  render "src/ecr/cap_invalid.ecr"
end

BASE_URL = ENV["BASE_URL"]

DATABASE = DB.open "sqlite3:./tugofvote.db"
DATABASE.exec "PRAGMA foreign_keys = ON"

enum CapKind
  # Administrate poll, disable voting etc.
  Admin = 5
  # Vote and add opinions
  Vote = 4
  # View, with added header that voting has been closed
  DisabledVote = 3
  # View
  View = 2
  # View but show no names
  ViewAnon = 1
  # Fail
  Revoked = 0

  def to_s
    case self
    when Admin
      "Administrate"
    when Vote
      "Vote"
    when DisabledVote
      "Vote (closed)"
    when View
      "View"
    when ViewAnon
      "View (anonymized)"
    end
  end
end

enum VoteKind
  Against = -1
  Neutral =  0
  InFavor =  1
end

Kemal.run ENV["PORT"].to_i
