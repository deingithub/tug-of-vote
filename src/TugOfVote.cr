require "kemal"
require "dotenv"
require "db"
require "sqlite3"
require "dotenv"

require "./Helpers"
require "./views/main"
require "./views/cap"
require "./views/new"

Dotenv.load!

BASE_URL = ENV["BASE_URL"]

DATABASE = DB.open "sqlite3:./tugofvote.db"
DATABASE.exec "PRAGMA foreign_keys = ON"

enum CapKind
  # Administrate List
  ListAdmin = 7
  # View List
  ListView = 6
  # Administrate poll, disable voting etc.
  PollAdmin = 5
  # Vote and add opinions
  PollVote = 4
  # View, with added header that voting has been closed
  PollDisabledVote = 3
  # View
  PollView = 2
  # View but show no names
  PollViewAnon = 1
  # Fail
  Revoked = 0

  def to_s
    case self
    when PollAdmin
      "Administrate"
    when PollVote
      "Vote"
    when PollDisabledVote
      "Vote (closed)"
    when PollView
      "View"
    when PollViewAnon
      "View (anonymized)"
    when ListAdmin
      "Administrate List"
    when ListView
      "View List"
    when Revoked
      "(Revoked)"
    end
  end
end

enum VoteKind
  Against = -1
  Neutral =  0
  InFavor =  1
end

Kemal.run ENV["PORT"].to_i
