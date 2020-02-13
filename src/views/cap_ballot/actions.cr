require "crypto/bcrypt/password"

post "/cap/:cap_slug/ballot/vote" do |env|
  name = HTML.escape(env.params.body["name"].as(String))
  password = HTML.escape(env.params.body["password"].as(String))

  error_text = ""
  error_text += validate_username(name)
  error_text += validate_password(password)
  unless error_text.empty?
    halt env, status_code: 400, response: tov_render "cap_invalid"
  end

  cap_data = fetch_cap(env.params.url["cap_slug"])
  if cap_data.nil? || (cap_data.kind != CapKind::BallotVote && cap_data.kind != CapKind::BallotAdmin)
    error_text = "Unauthorized. "
    halt env, status_code: 403, response: tov_render "cap_invalid"
  end

  ballot = DATABASE.query_all("select * from ballots where id = ?", cap_data.ballot_id, as: Ballot)[0]
  preferences = ballot.candidates.map { |x| {x, env.params.body[HTML.unescape(x)].to_i? || ballot.candidates.size + 1} }.to_h

  my_votes = DATABASE.query_all("select * from ballot_votes where ballot_id = ? and username = ?", cap_data.ballot_id, name, as: BallotVote)
  unless my_votes.empty?
    authorized = Crypto::Bcrypt::Password.new(my_votes[0].password).verify(password)
    unless authorized
      error_text = "Invalid Password. "
      halt env, status_code: 403, response: tov_render "cap_invalid"
    end
  end

  if preferences.values.any? { |x| x != ballot.candidates.size + 1 }
    # any preference set, update/create
    if my_votes.empty?
      hashed_password = Crypto::Bcrypt::Password.create(password).to_s
      DATABASE.exec(
        "insert into ballot_votes (username, password, ballot_id, preferences) values (?,?,?,?)",
        name,
        hashed_password,
        cap_data.ballot_id,
        DBAssociative.serialize(preferences)
      )
      LOG.info("ballot##{cap_data.ballot_id}: #{cap_data.cap_slug} created vote #{name}")
    else
      DATABASE.exec(
        "update ballot_votes set preferences = ?, created_at = current_timestamp where ballot_id = ? and username = ?",
        DBAssociative.serialize(preferences),
        cap_data.ballot_id,
        name
      )
      LOG.info("ballot##{cap_data.ballot_id}: #{cap_data.cap_slug} modified vote #{name}")
    end
  else
    # no preference set, delete
    if my_votes.empty?
      error_text = "You can't delete your vote if it hasn't been set before. "
      halt env, status_code: 400, response: tov_render "cap_invalid"
    end
    DATABASE.exec("delete from ballot_votes where ballot_id = ? and username = ?", cap_data.ballot_id, name)
    LOG.info("ballot##{cap_data.ballot_id}: #{cap_data.cap_slug} deleted vote #{name}")
  end

  all_preferences = DATABASE.query_all("select * from ballot_votes where ballot_id = ?", cap_data.ballot_id, as: BallotVote)
  updated_order = calculate_schulze_order(all_preferences.map(&.preferences))
  DATABASE.exec("update ballots set cached_result = ? where id = ?", DBAssociative.serialize(updated_order), cap_data.ballot_id)

  env.redirect "/cap/#{env.params.url["cap_slug"]}"
end

get "/cap/:cap_slug/ballot/end_voting" do |env|
  cap_data = fetch_cap(env.params.url["cap_slug"])
  if cap_data.nil? || cap_data.kind != CapKind::BallotAdmin
    error_text = "Unauthorized. "
    halt env, status_code: 403, response: tov_render "cap_invalid"
  end

  DATABASE.exec("update caps set kind = 9 where kind = 10 and ballot_id = ?", cap_data.ballot_id)
  LOG.info("ballot##{cap_data.ballot_id}: #{cap_data.cap_slug} closed voting")

  env.redirect "/cap/#{env.params.url["cap_slug"]}"
end

post "/cap/:cap_slug/ballot/update" do |env|
  cap_data = fetch_cap(env.params.url["cap_slug"])
  if cap_data.nil? || cap_data.kind != CapKind::BallotAdmin
    error_text = "Unauthorized. "
    halt env, status_code: 403, response: tov_render "cap_invalid"
  end

  title = HTML.escape(env.params.body["title"].as(String))
  error_text = validate_title(title)
  unless error_text.empty?
    halt env, status_code: 400, response: tov_render "cap_invalid"
  end

  DATABASE.exec("update ballots set title = ? where id = ?", title, cap_data.ballot_id)
  LOG.info("ballot##{cap_data.ballot_id}: #{cap_data.cap_slug} updated poll")

  env.redirect "/cap/#{env.params.url["cap_slug"]}"
end
