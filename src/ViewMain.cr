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
