get "/" do |env|
  send_file env, "public/index.html"
end
get "/help" do |env|
  send_file env, "public/help.html"
end
get "/new" do |env|
  list_param = env.params.query["list"]?
  list_cap = fetch_cap(list_param)
  if list_cap && list_cap.kind == CapKind::ListAdmin
    list = DATABASE.query_all("select * from lists where id = ?", list_cap.list_id, as: List)[0]
    next render "src/ecr/new_poll.ecr"
  else 
    list_cap = nil
  end
  render "src/ecr/new_poll.ecr"
end
get "/new_list" do |env|
  send_file env, "public/new_list.html"
end

error 404 do
  error_text = "This URL is unknown, invalid or has been revoked. Sorry."
  render "src/ecr/cap_invalid.ecr"
end

error 500 do
  error_text = "Internal server error. Please try again or contact the admin."
  render "src/ecr/cap_invalid.ecr"
end
