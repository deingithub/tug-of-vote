get "/cap/:cap_slug/list/remove/:target_slug" do |env|
  cap_data = fetch_cap(env.params.url["cap_slug"])
  fail(403, "Unauthorized.") if cap_data.nil? || cap_data.kind != CapKind::ListAdmin

  DATABASE.exec("delete from list_entries where list_id = ? and cap_slug = ?", cap_data.list_id, env.params.url["target_slug"])
  Log.info &.emit("removed list entry", id: cap_data.list_id, cap: cap_data.cap_slug, target_cap: env.params.url["target_slug"])

  env.redirect "/cap/#{env.params.url["cap_slug"]}"
end

post "/cap/:cap_slug/list/append" do |env|
  cap_data = fetch_cap(env.params.url["cap_slug"])
  fail(403, "Unauthorized.") if cap_data.nil? || cap_data.kind != CapKind::ListAdmin

  cap_slug = env.params.body["cap_url"].lchop(ENV["INSTANCE_BASE_URL"] + "/cap/")
  fail(400, "Unknown or invalid link.") unless fetch_cap(cap_slug)

  DATABASE.exec("insert into list_entries (list_id, cap_slug) values (?,?)", cap_data.list_id, cap_slug)
  Log.info &.emit("added list entry", id: cap_data.list_id, cap: cap_data.cap_slug, target_cap: cap_slug)

  spawn notify_list_addition(cap_data.list_id, cap_slug)
  env.redirect "/cap/#{env.params.url["cap_slug"]}"
end

post "/cap/:cap_slug/list/update" do |env|
  cap_data = fetch_cap(env.params.url["cap_slug"])
  fail(403, "Unauthorized.") if cap_data.nil? || cap_data.kind != CapKind::ListAdmin

  title, description, webhook_url = HTML.escape(env.params.body["title"].as(String)), HTML.escape(env.params.body["description"].as(String)), env.params.body["webhook_url"].as(String)
  validate_checks(
    validate_title(title),
    validate_content(description),
    validate_url(webhook_url)
  )

  DATABASE.exec("update lists set title = ?, description = ?, webhook_url = ? where id = ?", title, description, webhook_url, cap_data.list_id)
  Log.info &.emit("updated list content", id: cap_data.list_id, cap: cap_data.cap_slug)

  env.redirect "/cap/#{env.params.url["cap_slug"]}"
end

get "/cap/:cap_slug/list/regenerate_caps" do |env|
  cap_data = fetch_cap(env.params.url["cap_slug"])
  fail(403, "Unauthorized.") if cap_data.nil? || cap_data.kind != CapKind::ListAdmin

  admin_cap = make_cap()
  DATABASE.transaction do |trans|
    c = trans.connection
    c.exec("update caps set kind = 0 where list_id = ?", cap_data.list_id)
    c.exec("insert into caps (cap_slug, kind, list_id) values (?,?,?)", admin_cap, CapKind::ListAdmin.value, cap_data.list_id)
    c.exec("insert into caps (cap_slug, kind, list_id) values (?,?,?)", make_cap, CapKind::ListView.value, cap_data.list_id)
  end

  Log.info &.emit("regenerated list caps", id: cap_data.list_id, cap: cap_data.cap_slug, new_cap: admin_cap)
  env.redirect "/cap/#{admin_cap}"
end
