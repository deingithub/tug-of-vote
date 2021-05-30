post "/cap/:cap_slug/ballot/vote" do |env|
  name, password = HTML.escape(env.params.body["name"].to_s), HTML.escape(env.params.body["password"].to_s)
  cap_data = fetch_cap(env.params.url["cap_slug"])

  validate_checks(
    validate_username(name),
    validate_password(password)
  )
  fail(403, "Unauthorized.") if cap_data.nil? || (cap_data.kind != CapKind::BallotVote && cap_data.kind != CapKind::BallotAdmin)

  ballot = DATABASE.query_all("select * from ballots where id = ?", cap_data.ballot_id, as: Ballot)[0]

  preferences = (0...ballot.candidates.size).map { |candidate_number|
    candidate_ranking = env.params.body[candidate_number.to_s].to_i?
    {candidate_number, candidate_ranking || ballot.candidates.size + 1}
  }.to_h

  old_vote = DATABASE.query_all("select * from ballot_votes where ballot_id = ? and username = ?", cap_data.ballot_id, name, as: BallotVote)[0]? || nil

  if preferences.values.any? { |ranking| ranking != ballot.candidates.size + 1 }
    # at least some preferences are set, so update or create a record
    if old_vote
      fail(403, "Invalid Password.") unless valid_password(:ballot, cap_data.doc_id, name, password)

      DATABASE.exec(
        "update ballot_votes set preferences = ?, created_at = current_timestamp where ballot_id = ? and username = ?",
        preferences.to_json,
        cap_data.ballot_id,
        name
      )
      Log.info &.emit("updated ballot vote", id: cap_data.ballot_id, cap: cap_data.cap_slug, username: name)
    else
      DATABASE.exec(
        "insert into ballot_votes (username, password, ballot_id, preferences) values (?,?,?,?)",
        name,
        Crypto::Bcrypt::Password.create(password).to_s,
        cap_data.ballot_id,
        preferences.to_json
      )
      Log.info &.emit("created ballot vote", id: cap_data.ballot_id, cap: cap_data.cap_slug, username: name)
    end
  else
    # no preference set, delete
    if old_vote
      fail(403, "Invalid Password.") unless valid_password(:ballot, cap_data.doc_id, name, password)
    else
      fail(400, "You can't delete your vote if it hasn't been set before.") unless old_vote
    end

    DATABASE.exec("delete from ballot_votes where ballot_id = ? and username = ?", cap_data.ballot_id, name)
    Log.info &.emit("deleted ballot vote", id: cap_data.ballot_id, cap: cap_data.cap_slug, username: name)
  end

  all_votes = DATABASE.query_all("select * from ballot_votes where ballot_id = ?", cap_data.ballot_id, as: BallotVote)

  updated_order = (0...ballot.candidates.size).map { |n| {n, 1} }.to_h
  updated_order = calculate_schulze_order(all_votes.map(&.preferences)) unless all_votes.empty?

  DATABASE.exec("update ballots set cached_result = ? where id = ?", updated_order.to_json, cap_data.ballot_id)

  env.redirect "/cap/#{env.params.url["cap_slug"]}"
end

get "/cap/:cap_slug/ballot/end_voting" do |env|
  cap_data = fetch_cap(env.params.url["cap_slug"])

  fail(403, "Unauthorized.") if cap_data.nil? || cap_data.kind != CapKind::BallotAdmin

  DATABASE.exec("update caps set kind = 9 where kind = 10 and ballot_id = ?", cap_data.ballot_id)
  Log.info &.emit("closed ballot", id: cap_data.ballot_id, cap: cap_data.cap_slug)

  env.redirect "/cap/#{env.params.url["cap_slug"]}"
end

post "/cap/:cap_slug/ballot/update" do |env|
  cap_data = fetch_cap(env.params.url["cap_slug"])

  fail(403, "Unauthorized.") if cap_data.nil? || cap_data.kind != CapKind::BallotAdmin

  title, description = HTML.escape(env.params.body["title"].as(String)), HTML.escape(env.params.body["description"].as(String))
  validate_checks(validate_title(title))

  DATABASE.exec("update ballots set title = ?, description = ? where id = ?", title, description, cap_data.ballot_id)
  Log.info &.emit("updated ballot", id: cap_data.ballot_id, cap: cap_data.cap_slug)

  env.redirect "/cap/#{env.params.url["cap_slug"]}"
end
