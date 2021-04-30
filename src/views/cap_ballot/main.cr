def gen_ballot(cap)
  ballot = DATABASE.query_all("select * from ballots where id = ?", cap.ballot_id, as: Ballot)[0]
  og_desc = case cap.kind
            when CapKind::BallotAdmin
              "You were supposed to keep this link private, s m h"
            when CapKind::BallotVote
              "Cast your vote in this ballot on Tug of Vote"
            else
              "View this ballot on Tug of Vote"
            end

  if (
       ballot.duration &&
       (cap.kind == CapKind::BallotVote || cap.kind == CapKind::BallotAdmin) &&
       (ballot.created_at + ballot.duration.not_nil!) <= Time.utc
     )
    DATABASE.exec("update caps set kind = 9 where kind = 10 and ballot_id = ?", cap.ballot_id)
    Log.info &.emit("auto-closed ballot", id: cap.ballot_id, slug: cap.cap_slug)

    if cap.kind == CapKind::BallotVote
      cap.kind = CapKind::BallotVoteDisabled
      gen_ballot(cap)
    end
  end

  cached_result = ballot.cached_result                                                  # {candidate id => paths beaten}
    .to_a                                                                               # [{candidate id, paths}]
    .group_by { |candidate, paths| paths }                                              # {paths => [candidate id, candidate id]}
    .transform_values { |v| v.map { |candidate, paths| ballot.candidates[candidate] } } # {paths => [candidate, candidate]}
    .to_a                                                                               # [{paths, [candidate, candidate]}, {paths, [candidate]}]
    .sort_by { |paths, candidates| paths }
    .reverse
    .map { |paths, candidates| candidates } # [[candidate, candidate], [candidate]]

  close_timestamp = nil
  close_timestamp = (ballot.created_at + ballot.duration.not_nil!).to_unix_ms if ballot.duration

  votes = DATABASE.query_all("select * from ballot_votes where ballot_id = ?", cap.ballot_id, as: BallotVote)
  lower_caps = DATABASE.query_all("select * from caps where ballot_id = ? and kind <= ? and kind > ?", cap.ballot_id, cap.kind_val, CapKind::Revoked.value, as: Cap)

  tov_render "cap_ballot"
end
