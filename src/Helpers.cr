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
  return "Content may not be empty. " if content.empty?
  return "Content may not exceed 20000 characters (currently #{str.size}). " if str.size > 20000
  return ""
end