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

  # fetch relevant cap and ensure we're allowed to vote
  cap_data = nil
  rs = DATABASE.query "select poll_id, kind from caps where cap_slug = ?", env.params.url["cap_slug"]
  if rs.move_next
    cap_row = rs.read(poll_id: Int64, kind: Int64)
    cap_data = {poll_id: cap_row[:poll_id], kind: CapKind.from_value(cap_row[:kind])}
    if cap_data[:kind] != CapKind::PollVote && cap_data[:kind] != CapKind::PollAdmin
      rs.close
      error_text = "Unauthorized. "
      halt env, status_code: 403, response: render "src/ecr/cap_invalid.ecr"
    end
    rs.close
  else
    rs.close
    error_text = "Unauthorized. "
    halt env, status_code: 403, response: render "src/ecr/cap_invalid.ecr"
  end

  # if an older vote exists, check password before continuing
  has_old = false
  rs = DATABASE.query "select password from votes where poll_id = ? and username = ?", cap_data.not_nil![:poll_id], name
  if rs.move_next
    db_password = rs.read(String)
    authorized = Crypto::Bcrypt::Password.new(db_password).verify(password)
    rs.close
    unless authorized
      error_text = "Unauthorized. "
      halt env, status_code: 403, response: render "src/ecr/cap_invalid.ecr"
    end
    has_old = true
  else
    rs.close
  end

  # at this point we are both authorized to vote and have either a valid password or a new user
  if vote == "delvote"
    unless has_old 
      error_text = "You can't delete your vote if it hasn't been set before. "
      halt env, status_code: 400, response: render "src/ecr/cap_invalid.ecr" 
    end
    DATABASE.exec "delete from votes where poll_id = ? and username = ?", cap_data.not_nil![:poll_id], name
  else
    vote_enum = VoteKind.parse(vote)
    if has_old
      DATABASE.exec "update votes set kind = ?, reason = ?, created_at = current_timestamp where poll_id = ? and username = ?", vote_enum.value, reason, cap_data.not_nil![:poll_id], name
    else
      hashed_password = Crypto::Bcrypt::Password.create(password).to_s
      DATABASE.exec "insert into votes (kind, username, password, reason, poll_id) values (?,?,?,?,?)", vote_enum.value, name, hashed_password, reason, cap_data.not_nil![:poll_id]
    end
  end

  env.response.status_code = 303
  env.response.headers.add("Location", "/cap/#{env.params.url["cap_slug"]}")
end

post "/cap/:cap_slug/poll/end_voting" do |env|
  # fetch relevant cap and ensure we're allowed to administrate
  cap_data = nil
  rs = DATABASE.query "select poll_id, kind from caps where cap_slug = ?", env.params.url["cap_slug"]
  if rs.move_next
    cap_row = rs.read(poll_id: Int64, kind: Int64)
    cap_data = {poll_id: cap_row[:poll_id], kind: CapKind.from_value(cap_row[:kind])}
    if cap_data[:kind] != CapKind::PollAdmin
      rs.close
      error_text = "Unauthorized. "
      halt env, status_code: 403, response: render "src/ecr/cap_invalid.ecr"
    end
    rs.close
  else
    rs.close
    error_text = "Unauthorized. "
    halt env, status_code: 403, response: render "src/ecr/cap_invalid.ecr"
  end
  DATABASE.exec "update caps set kind = 3 where kind = 4 and poll_id = ?", cap_data.not_nil![:poll_id]
  env.response.status_code = 302
  env.response.headers.add("Location", "/cap/#{env.params.url["cap_slug"]}")
end

post "/cap/:cap_slug/poll/update" do |env|
  title = HTML.escape(env.params.body["title"].as(String))
  description = HTML.escape(env.params.body["description"].as(String))
  error_text = ""
  error_text += validate_title(title)
  error_text += validate_content(description)
  unless error_text.empty?
    halt env, status_code: 400, response: render "src/ecr/cap_invalid.ecr"
  end
  # fetch relevant cap and ensure we're allowed to administrate
  cap_data = nil
  rs = DATABASE.query "select poll_id, kind from caps where cap_slug = ?", env.params.url["cap_slug"]
  if rs.move_next
    cap_row = rs.read(poll_id: Int64, kind: Int64)
    cap_data = {poll_id: cap_row[:poll_id], kind: CapKind.from_value(cap_row[:kind])}
    if cap_data[:kind] != CapKind::PollAdmin
      rs.close
      error_text = "Unauthorized. "
      halt env, status_code: 403, response: render "src/ecr/cap_invalid.ecr"
    end
    rs.close
  else
    rs.close
    error_text = "Unauthorized. "
    halt env, status_code: 403, response: render "src/ecr/cap_invalid.ecr"
  end
  DATABASE.exec "update polls set title = ?, description = ? where id = ?", title, description, cap_data.not_nil![:poll_id]
  env.response.status_code = 303
  env.response.headers.add("Location", "/cap/#{env.params.url["cap_slug"]}")
end