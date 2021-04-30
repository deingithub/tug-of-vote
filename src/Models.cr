# Monkeypatches for things we want to be able to deserialize

# enums are stored as integers
struct Enum
  include DB::Mappable

  def self.new(rs : DB::ResultSet)
    self.from_value(rs.read(Int64))
  end
end

# arrays are stored as JSON
class Array
  include DB::Mappable

  def self.new(rs : DB::ResultSet)
    self.from_json(rs.read.to_s)
  end
end

# hashes are stored as JSON
class Hash
  include DB::Mappable

  def self.new(rs : DB::ResultSet)
    self.from_json(rs.read.to_s)
  end
end

class HoursToTimeSpan
  def self.from_rs(rs : DB::ResultSet)
    if read_value = rs.read(Int64 | Nil)
      Time::Span.new(hours: read_value)
    else
      nil
    end
  end
end

enum CapKind
  # Edit Document
  DocEdit = 21
  # View Document
  DocView = 20
  # Administrate Ballot
  BallotAdmin = 11
  # Vote in Ballot
  BallotVote = 10
  # Vote in Ballot, disabled
  BallotVoteDisabled = 9
  # View Ballot
  BallotView = 8
  # Administrate List
  ListAdmin = 7
  # View List
  ListView = 6
  # Administrate poll, disable voting etc.
  PollAdmin = 5
  # Vote and add opinions
  PollVote = 4
  # View, with added header that voting has been closed
  PollVoteDisabled = 3
  # View
  PollView = 2
  # View but show no names
  PollViewAnon = 1
  # Fail
  Revoked = 0

  def to_s
    case self
    in PollAdmin, BallotAdmin
      "Administrate"
    in PollVote, BallotVote
      "Vote"
    in PollVoteDisabled, BallotVoteDisabled
      "Vote (closed)"
    in PollView, BallotView, DocView
      "View"
    in PollViewAnon
      "View (anonymized)"
    in ListAdmin
      "Administrate List"
    in ListView
      "View List"
    in DocEdit
      "Edit"
    in Revoked
      "(Revoked)"
    end
  end

  def to_verb
    case self
    in BallotAdmin
      "Administrate Ballot"
    in BallotView, BallotVoteDisabled
      "View Ballot"
    in PollAdmin
      "Administrate Poll"
    in PollVote, BallotVote
      "Vote on"
    in PollVoteDisabled, PollView, PollViewAnon
      "View Poll"
    in ListAdmin
      "Administrate List"
    in ListView
      "View List"
    in DocEdit
      "Edit Doc"
    in DocView
      "View Doc"
    in Revoked
      "(Revoked)"
    end
  end
end

enum VoteKind
  Against = -1
  Neutral =  0
  InFavor =  1

  def to_s
    "In Favor" if self == InFavor
    previous_def
  end
end

class Cap
  DB.mapping({
    cap_slug:  String,
    kind:      CapKind,
    poll_id:   Int64?,
    list_id:   Int64?,
    ballot_id: Int64?,
    doc_id:    Int64?,
  })

  def kind_val
    kind.value
  end
end

class Poll
  DB.mapping({
    id:          Int64,
    created_at:  Time,
    title:       String,
    description: String,
    duration:    {type: Time::Span, nilable: true, converter: HoursToTimeSpan},
  })
end

class Vote
  DB.mapping({
    kind:       VoteKind,
    username:   String,
    password:   String,
    reason:     String,
    created_at: Time,
    poll_id:    Int64,
  })
end

class List
  DB.mapping({
    id:          Int64,
    created_at:  Time,
    description: String,
    title:       String,
    webhook_url: String,
  })
end

class ListEntry
  DB.mapping({
    list_id:  Int64,
    cap_slug: String,
  })
end

class Ballot
  DB.mapping({
    id:            Int64,
    created_at:    Time,
    title:         String,
    candidates:    Array(String),
    duration:      {type: Time::Span, nilable: true, converter: HoursToTimeSpan},
    cached_result: Hash(Int64, Int64),
    hide_names:    Bool,
  })
end

class BallotVote
  DB.mapping({
    ballot_id:   Int64,
    username:    String,
    password:    String,
    created_at:  Time,
    preferences: Hash(Int64, Int64),
  })
end

class Doc
  DB.mapping({
    id:         Int64,
    created_at: Time,
    title:      String,
  })
end

class DocUser
  DB.mapping({
    doc_id:   Int64,
    username: String,
    password: String,
  })
end

class DocRevision
  DB.mapping({
    id:                 Int64,
    doc_id:             Int64,
    created_at:         Time,
    comment:            String,
    revision_diff:      String?,
    parent_revision_id: Int64?,
    username:           String,
  })
end

class DocRevisionReaction
  DB.mapping({
    doc_id:      Int64,
    revision_id: Int64,
    username:    String,
    kind:        VoteKind,
  })
end
