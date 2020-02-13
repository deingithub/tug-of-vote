enum CapKind
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
    when PollAdmin, BallotAdmin
      "Administrate"
    when PollVote, BallotVote
      "Vote"
    when PollVoteDisabled, BallotVoteDisabled
      "Vote (closed)"
    when PollView, BallotView
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

  def to_verb
    case self
    when BallotAdmin
      "Administrate Ballot"
    when BallotView, BallotVoteDisabled
      "View Ballot"
    when PollAdmin
      "Administrate Poll"
    when PollVote, BallotVote
      "Vote on"
    when PollVoteDisabled, PollView, PollViewAnon
      "View Poll"
    when ListAdmin
      "Administrate List"
    when ListView
      "View List"
    when Revoked
      "(Revoked)"
    end
  end

  def self.from_rs(rs)
    self.from_value(rs.read(Int64))
  end
end

enum VoteKind
  Against = -1
  Neutral =  0
  InFavor =  1

  def self.from_rs(rs)
    self.from_value(rs.read(Int64))
  end
end

# Helper class to safely read strings from the database.
# Currently, for some reason reading a normal String that consists entirely
# out of digits raises an exception.

class DBString
  def self.from_rs(rs)
    rs.read.to_s
  end
end

class DBList
  def self.from_rs(rs)
    rs.read.to_s.split(",").map { |x| Base64.decode_string(x) }
  end

  def self.serialize(arr)
    arr.map { |x| Base64.strict_encode(x) }.join(",")
  end
end

class DBAssociative
  def self.from_rs(rs)
    rs.read.to_s.split(",").map { |x|
      kv = x.split(":")
      {Base64.decode_string(kv[0]), Base64.decode_string(kv[1])}
    }.to_h
  end

  def self.serialize(hash)
    hash.to_a.map { |k, v| Base64.strict_encode(k.to_s) + ":" + Base64.strict_encode(v.to_s) }.join(",")
  end
end

class Cap
  DB.mapping({
    cap_slug:  String,
    kind:      {type: CapKind, converter: CapKind},
    poll_id:   Int64?,
    list_id:   Int64?,
    ballot_id: Int64?,
  })

  def kind_val
    kind.value
  end
end

class Poll
  DB.mapping({
    id:          Int64,
    created_at:  String,
    title:       {type: String, converter: DBString},
    description: {type: String, converter: DBString},
    duration:    Int64?,
  })
end

class Vote
  DB.mapping({
    kind:       {type: VoteKind, converter: VoteKind},
    username:   {type: String, converter: DBString},
    password:   {type: String, converter: DBString},
    reason:     {type: String, converter: DBString},
    created_at: String,
    poll_id:    Int64,
  })
end

class List
  DB.mapping({
    id:          Int64,
    created_at:  String,
    description: {type: String, converter: DBString},
    title:       {type: String, converter: DBString},
    webhook_url: {type: String, converter: DBString},
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
    created_at:    String,
    title:         {type: String, converter: DBString},
    candidates:    {type: Array(String), converter: DBList},
    duration:      Int64?,
    cached_result: {type: Hash(String, String), converter: DBAssociative},
  })
end

class BallotVote
  DB.mapping({
    ballot_id:   Int64,
    username:    {type: String, converter: DBString},
    password:    {type: String, converter: DBString},
    created_at:  String,
    preferences: {type: Hash(String, String), converter: DBAssociative},
  })
end
