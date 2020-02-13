get "/" do |env|
  tov_render "static_index"
end

get "/help" do |env|
  tov_render "static_help"
end

get "/new" do |env|
  list_param = env.params.query["list"]?
  list_cap = fetch_cap(list_param)
  if list_cap && list_cap.kind == CapKind::ListAdmin
    list = DATABASE.query_all("select * from lists where id = ?", list_cap.list_id, as: List)[0]
    next tov_render "new_poll"
  else
    list_cap = nil
  end
  tov_render "new_poll"
end

get "/new_list" do |env|
  tov_render "new_list"
end

get "/new_ballot" do |env|
  tov_render "new_ballot"
end

error 404 do
  error_text = "This URL is unknown, invalid or has been revoked. Sorry."
  tov_render "cap_invalid"
end

error 500 do
  error_text = "Internal server error. Please try again or contact the admin."
  tov_render "cap_invalid"
end
