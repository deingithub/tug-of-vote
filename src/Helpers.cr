# Yes this is not an antipattern.
# Trust me.

def validate_username(str)
  return "Username may not be empty. " if str.empty?
  return "Username may not exceed 42 characters. " if str.size > 42
  return ""
end

def validate_password(str)
  return "Password may not be empty. " if str.empty?
  return "Password may not exceed 70 characters. " if str.size > 70
  return ""
end

def validate_reason(str)
  return "Reason may not exceed 2000 characters (currently #{str.size}). " if str.size > 2000
  return ""
end

def validate_content(str)
  return "Content may not be empty. " if str.empty?
  return "Content may not exceed 20000 characters (currently #{str.size}). " if str.size > 20000
  return ""
end

def validate_title(str)
  return "Title may not be empty. " if str.empty?
  return "Title may not exceed 200 characters (currently #{str.size}). " if str.size > 200
  return ""
end

def fetch_cap(cap_slug)
  arr = DATABASE.query_all("select * from caps where cap_slug = ?", cap_slug, as: Cap)
  if arr.empty?
    return nil
  else
    return arr[0]
  end
end

def content_to_html(str)
  str.gsub("\n", "<br>")
end