get "/cap/:cap_slug/list/remove/:target_slug" do |env|
  # fetch relevant cap and ensure we're allowed to administrate
  cap_data = nil
  rs = DATABASE.query "select list_id, kind from caps where cap_slug = ?", env.params.url["cap_slug"]
  if rs.move_next
    cap_row = rs.read(list_id: Int64, kind: Int64)
    cap_data = {list_id: cap_row[:list_id], kind: CapKind.from_value(cap_row[:kind])}
    if cap_data[:kind] != CapKind::ListAdmin
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
  DATABASE.exec "delete from list_entries where list_id = ? and cap_slug = ?", cap_data.not_nil![:list_id], env.params.url["target_slug"]
  env.response.status_code = 302
  env.response.headers.add("Location", "/cap/#{env.params.url["cap_slug"]}")
end

post "/cap/:cap_slug/list/append" do |env|
  cap_slug = env.params.body["cap_url"].lchop(BASE_URL + "/cap/")
  valid_cap = DATABASE.scalar("select count(*) from caps where cap_slug = ?", cap_slug).as(Int64) == 1
  unless valid_cap
    error_text = "Unknown or invalid link. "
    halt env, status_code: 400, response: render "src/ecr/cap_invalid.ecr" 
  end

  # fetch relevant cap and ensure we're allowed to administrate
  cap_data = nil
  rs = DATABASE.query "select list_id, kind from caps where cap_slug = ?", env.params.url["cap_slug"]
  if rs.move_next
    cap_row = rs.read(list_id: Int64, kind: Int64)
    cap_data = {list_id: cap_row[:list_id], kind: CapKind.from_value(cap_row[:kind])}
    if cap_data[:kind] != CapKind::ListAdmin
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

  DATABASE.exec "insert into list_entries (list_id, cap_slug) values (?,?)", cap_data.not_nil![:list_id], cap_slug
  env.response.status_code = 302
  env.response.headers.add("Location", "/cap/#{env.params.url["cap_slug"]}")
end

post "/cap/:cap_slug/list/update" do |env|
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
  rs = DATABASE.query "select list_id, kind from caps where cap_slug = ?", env.params.url["cap_slug"]
  if rs.move_next
    cap_row = rs.read(list_id: Int64, kind: Int64)
    cap_data = {list_id: cap_row[:list_id], kind: CapKind.from_value(cap_row[:kind])}
    if cap_data[:kind] != CapKind::ListAdmin
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
  DATABASE.exec "update lists set title = ?, description = ? where id = ?", title, description, cap_data.not_nil![:list_id]
  env.response.status_code = 303
  env.response.headers.add("Location", "/cap/#{env.params.url["cap_slug"]}")
end