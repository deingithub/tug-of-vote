require "crypto/bcrypt/password"

post "/cap/:cap_slug/vote" do |env|
  name = env.params.body["name"].as(String)
  password = env.params.body["password"].as(String)
  vote = env.params.body["vote"].as(String)
  reason = env.params.body["reason"].as(String)

  error_text = ""
  if password.empty?
    error_text += "Password may not be empty. "
  end
  # necessary due to the hashing algorithm used
  if password.size > 70
    error_text += "Maximum password length is 70 characters. "
  end
  # ruining your fun since 1661
  if name.size > 42
    error_text += "Maximum name length is 42 characters. "
  end
  if reason.size > 2000
    error_text += "Maximum reason length is 2000 characters. "
  end
  unless error_text.empty?
    halt env, status_code: 400, response: render "src/ecr/cap_invalid.ecr"
  end

  # fetch relevant cap and ensure we're allowed to vote
  cap_data = nil
  rs = DATABASE.query "select poll_id, kind from caps where cap_slug = ?", env.params.url["cap_slug"]
  if rs.move_next
    cap_row = rs.read(poll_id: Int64, kind: Int64)
    cap_data = {poll_id: cap_row[:poll_id], kind: CapKind.from_value(cap_row[:kind])}
    if cap_data[:kind] != CapKind::Vote && cap_data[:kind] != CapKind::Admin
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

get "/cap/:cap_slug/admin/end_voting" do |env|
  # fetch relevant cap and ensure we're allowed to administrate
  cap_data = nil
  rs = DATABASE.query "select poll_id, kind from caps where cap_slug = ?", env.params.url["cap_slug"]
  if rs.move_next
    cap_row = rs.read(poll_id: Int64, kind: Int64)
    cap_data = {poll_id: cap_row[:poll_id], kind: CapKind.from_value(cap_row[:kind])}
    if cap_data[:kind] != CapKind::Admin
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
