require "crypto/bcrypt/password"

post "/cap/:cap_slug/poll/vote" do |env|
  name = HTML.escape(env.params.body["name"].as(String))
  password = HTML.escape(env.params.body["password"].as(String))
  vote = HTML.escape(env.params.body["vote"].as(String))
  reason = HTML.escape(env.params.body["reason"].as(String))

  error_text = ""
  error_text += validate_username(name)
  error_text += validate_reason(reason)
  error_text += validate_password(password)
  unless error_text.empty?
    halt env, status_code: 400, response: render "src/ecr/cap_invalid.ecr"
  end

  cap_data = fetch_cap(env.params.url["cap_slug"])
  if cap_data.nil? || (cap_data.kind != CapKind::PollVote && cap_data.kind != CapKind::PollAdmin)
    error_text = "Unauthorized. "
    halt env, status_code: 403, response: render "src/ecr/cap_invalid.ecr"
  end

  votes = DATABASE.query_all("select * from votes where poll_id = ? and username = ?", cap_data.poll_id, name, as: Vote)
  unless votes.empty?
    authorized = Crypto::Bcrypt::Password.new(votes[0].password).verify(password)
    unless authorized
      error_text = "Invalid Password. "
      halt env, status_code: 403, response: render "src/ecr/cap_invalid.ecr"
    end
  end

  # at this point we are both authorized to vote and have either a valid password or a new user
  if vote == "delvote"
    if votes.empty?
      error_text = "You can't delete your vote if it hasn't been set before. "
      halt env, status_code: 400, response: render "src/ecr/cap_invalid.ecr"
    end
    DATABASE.exec "delete from votes where poll_id = ? and username = ?", cap_data.poll_id, name

    LOG.info("poll##{cap_data.poll_id}: #{cap_data.cap_slug} deleted vote #{name}")
  else
    vote_enum = VoteKind.parse(vote)
    unless votes.empty?
      DATABASE.exec "update votes set kind = ?, reason = ?, created_at = current_timestamp where poll_id = ? and username = ?", vote_enum.value, reason, cap_data.poll_id, name

      LOG.info("poll##{cap_data.poll_id}: #{cap_data.cap_slug} modified #{name}")
    else
      hashed_password = Crypto::Bcrypt::Password.create(password).to_s
      DATABASE.exec "insert into votes (kind, username, password, reason, poll_id) values (?,?,?,?,?)", vote_enum.value, name, hashed_password, reason, cap_data.poll_id

      LOG.info("poll##{cap_data.poll_id}: #{cap_data.cap_slug} created vote #{name}")
    end
  end

  env.response.status_code = 303
  env.response.headers.add("Location", "/cap/#{env.params.url["cap_slug"]}")
end

get "/cap/:cap_slug/poll/end_voting" do |env|
  cap_data = fetch_cap(env.params.url["cap_slug"])
  if cap_data.nil? || cap_data.kind != CapKind::PollAdmin
    error_text = "Unauthorized. "
    halt env, status_code: 403, response: render "src/ecr/cap_invalid.ecr"
  end

  DATABASE.exec "update caps set kind = 3 where kind = 4 and poll_id = ?", cap_data.poll_id
  LOG.info("poll##{cap_data.poll_id}: #{cap_data.cap_slug} closed voting")

  env.response.status_code = 302
  env.response.headers.add("Location", "/cap/#{env.params.url["cap_slug"]}")
end

post "/cap/:cap_slug/poll/update" do |env|
  cap_data = fetch_cap(env.params.url["cap_slug"])
  if cap_data.nil? || cap_data.kind != CapKind::PollAdmin
    error_text = "Unauthorized. "
    halt env, status_code: 403, response: render "src/ecr/cap_invalid.ecr"
  end

  title = HTML.escape(env.params.body["title"].as(String))
  description = HTML.escape(env.params.body["description"].as(String))
  error_text = ""
  error_text += validate_title(title)
  error_text += validate_content(description)
  unless error_text.empty?
    halt env, status_code: 400, response: render "src/ecr/cap_invalid.ecr"
  end

  DATABASE.exec "update polls set title = ?, description = ? where id = ?", title, description, cap_data.poll_id
  LOG.info("poll##{cap_data.poll_id}: #{cap_data.cap_slug} updated poll")

  env.response.status_code = 303
  env.response.headers.add("Location", "/cap/#{env.params.url["cap_slug"]}")
end
