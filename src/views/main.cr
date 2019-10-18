get "/" do |env|
  send_file env, "public/index.html"
end
get "/help" do |env|
  send_file env, "public/help.html"
end
get "/new" do |env|
  send_file env, "public/new.html"
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
