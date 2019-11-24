get "/cap/:cap_slug/list/remove/:target_slug" do |env|
  cap_data = fetch_cap(env.params.url["cap_slug"])
  if cap_data.nil? || cap_data.kind != CapKind::ListAdmin
    error_text = "Unauthorized. "
    halt env, status_code: 403, response: render "src/ecr/cap_invalid.ecr"
  end

  DATABASE.exec "delete from list_entries where list_id = ? and cap_slug = ?", cap_data.list_id, env.params.url["target_slug"]

  LOG.info("list##{cap_data.list_id}: #{cap_data.cap_slug} removed entry #{env.params.url["target_slug"]}")

  env.response.status_code = 302
  env.response.headers.add("Location", "/cap/#{env.params.url["cap_slug"]}")
end

post "/cap/:cap_slug/list/append" do |env|
  cap_data = fetch_cap(env.params.url["cap_slug"])
  if cap_data.nil? || cap_data.kind != CapKind::ListAdmin
    error_text = "Unauthorized. "
    halt env, status_code: 403, response: render "src/ecr/cap_invalid.ecr"
  end

  cap_slug = env.params.body["cap_url"].lchop(BASE_URL + "/cap/")
  unless fetch_cap(cap_slug)
    error_text = "Unknown or invalid link. "
    halt env, status_code: 400, response: render "src/ecr/cap_invalid.ecr"
  end

  DATABASE.exec "insert into list_entries (list_id, cap_slug) values (?,?)", cap_data.list_id, cap_slug

  LOG.info("list##{cap_data.list_id}: #{cap_data.cap_slug} added entry #{cap_slug}")
  notify_list_addition(cap_data.list_id, cap_slug)

  env.response.status_code = 302
  env.response.headers.add("Location", "/cap/#{env.params.url["cap_slug"]}")
end

post "/cap/:cap_slug/list/update" do |env|
  title = HTML.escape(env.params.body["title"].as(String))
  description = HTML.escape(env.params.body["description"].as(String))
  webhook_url = env.params.body["webhook_url"].as(String)
  error_text = ""
  error_text += validate_title(title)
  error_text += validate_content(description)
  error_text += validate_url(webhook_url)
  unless error_text.empty?
    halt env, status_code: 400, response: render "src/ecr/cap_invalid.ecr"
  end

  cap_data = fetch_cap(env.params.url["cap_slug"])
  if cap_data.nil? || cap_data.kind != CapKind::ListAdmin
    error_text = "Unauthorized. "
    halt env, status_code: 403, response: render "src/ecr/cap_invalid.ecr"
  end

  DATABASE.exec "update lists set title = ?, description = ?, webhook_url = ? where id = ?", title, description, webhook_url, cap_data.list_id

  LOG.info("list##{cap_data.list_id}: #{cap_data.cap_slug} updated content")

  env.response.status_code = 303
  env.response.headers.add("Location", "/cap/#{env.params.url["cap_slug"]}")
end

get "/cap/:cap_slug/list/regenerate_caps" do |env|
  cap_data = fetch_cap(env.params.url["cap_slug"])
  if cap_data.nil? || cap_data.kind != CapKind::ListAdmin
    error_text = "Unauthorized. "
    halt env, status_code: 403, response: render "src/ecr/cap_invalid.ecr"
  end

  admin_cap = make_cap()
  DATABASE.transaction do |tx|
    c = tx.connection
    c.exec("update caps set kind = 0 where list_id = ?", cap_data.list_id)
    c.exec("insert into caps (cap_slug, kind, list_id) values (?,?,?)", admin_cap, CapKind::ListAdmin.value, cap_data.list_id)
    c.exec("insert into caps (cap_slug, kind, list_id) values (?,?,?)", make_cap, CapKind::ListView.value, cap_data.list_id)
    LOG.info("list##{cap_data.list_id}: #{cap_data.cap_slug} regenerated caps, now #{admin_cap}")
  end

  env.response.status_code = 302
  env.response.headers.add("Location", "/cap/#{admin_cap}")
end
