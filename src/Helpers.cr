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
  return "Content may not exceed 99907 characters (currently #{str.size}). " if str.size > 99907
  return ""
end

def validate_title(str)
  return "Title may not be empty. " if str.empty?
  return "Title may not exceed 200 characters (currently #{str.size}). " if str.size > 200
  return ""
end

def validate_url(str)
  return "URL may not exceed 512 characters. " if str.size > 512
  return ""
end

def validate_duration(val)
  if val
    return "Duration may not be zero. " if val == 0
    return "Duration may not be greater than a year. " if val > 8760
  end
  return ""
end

def validate_candidate_list(arr)
  return "Must have at least two candidates. " if arr.size < 2
  return "Must not have more than 50 candidates. " if arr.size > 50
  return "Individual candidates may not exceed 100 characters. " if arr.any? { |x| x.size > 100 }
  return ""
end

def fetch_cap(cap_slug)
  DATABASE.query_all("select * from caps where cap_slug = ?", cap_slug, as: Cap)[0]?
end

def content_to_html(str)
  str.gsub("\n", "<br>")
end

# ~~Based on~~ Stolen from Kemal's default logger, writes to global LOG instead
class ToVLogger < Kemal::BaseLogHandler
  def call(context : HTTP::Server::Context)
    time = Time.utc
    call_next(context)
    elapsed_text = elapsed_text(Time.utc - time)
    LOG.debug "#{context.response.status_code} #{context.request.method} #{context.request.resource} #{elapsed_text}"
    context
  end

  def write(message : String)
    LOG.info(message.rchop("\n"))
  end

  private def elapsed_text(elapsed)
    millis = elapsed.total_milliseconds
    return "#{millis.round(2)}ms" if millis >= 1

    "#{(millis * 1000).round(2)}µs"
  end
end

macro tov_render(filename)
  render "src/ecr/#{{{filename}}}.ecr", "src/ecr/master.ecr"
end

def pluralize(count, singular, plural = nil)
  if count.abs == 1
    return "#{count}&nbsp;#{singular}"
  else
    return "#{count}&nbsp;#{plural ? plural : singular + "s"}"
  end
end

def valid_password(kind, id, username, password)
  stored_password = case kind
                    when :poll
                      DATABASE.query_one?(
                        "select password from votes where poll_id = ? and username = ?",
                        id, username, as: String
                      )
                    when :ballot
                      DATABASE.query_one?(
                        "select password from ballot_votes where ballot_id = ? and username = ?",
                        id, username, as: String
                      )
                    when :doc
                      DATABASE.query_one?(
                        "select password from doc_users where doc_id = ? and username = ?",
                        id, username, as: String
                      )
                    else
                      raise "Unreachable"
                    end
  return true unless stored_password
  return Crypto::Bcrypt::Password.new(stored_password).verify(password)
end

# TODO add testing to verify, passed some manual tests.
# Input: All Ballot votes in the form of "Candidate" => Ranking No. (String due to DB)
# Output: Candidate order in the form of "Candidate" => Other paths beat
#         The candidate with the highest number wins.
def calculate_schulze_order(preferences : Array(Hash(String, String))) : Hash(String, Int32)
  raise "Unreachable" if preferences.empty?
  candidates = preferences[0].keys

  # build pairwise preferences table
  pairwise_preferences = Hash(String, Hash(String, Int64)).new(Hash(String, Int64).new(0))
  candidates.each do |candidate|
    candidate_preferences = Hash(String, Int64).new(0)
    preferences.each do |vote|
      vote.to_a.each do |vote_candidate, vote_order|
        candidate_preferences[vote_candidate] += 1 if vote_order.to_i > vote[candidate].to_i
      end
    end
    pairwise_preferences[candidate] = candidate_preferences
  end

  # calculate path strengths with an adapted floyd-warshall algorithm
  # ported from wikipedia: https://en.wikipedia.org/w/index.php?title=Schulze_method&oldid=940574379#Implementation
  path_strengths = Hash(String, Hash(String, Int64)).new(Hash(String, Int64).new(0))
  candidates.each do |i|
    candidates.each do |j|
      next if i == j
      path_strengths[i] = Hash(String, Int64).new(0) unless path_strengths[i]?
      if pairwise_preferences[i][j] > pairwise_preferences[j][i]
        path_strengths[i][j] = pairwise_preferences[i][j]
      else
        path_strengths[i][j] = 0
      end
    end
  end
  candidates.each do |i|
    candidates.each do |j|
      next if i == j
      candidates.each do |k|
        next if i == k || j == k
        path_strengths[j][k] = Math.max(path_strengths[j][k], Math.min(path_strengths[j][i], path_strengths[i][k]))
      end
    end
  end

  # build result hash from strongest paths
  candidates.map { |candidate|
    stronger_paths = path_strengths[candidate].to_a.select { |to_candidate, strength|
      strength > path_strengths[to_candidate][candidate]
    }
    {candidate, stronger_paths.size}
  }.to_h
end

alias DiffType = Array(Tuple(Int64, String? | Int64))

# Generate a JSON-able diff between two strings
def diff(old : String, new : String) : DiffType
  result = [] of Tuple(Int64, String? | Int64)
  Math.max(old.lines.size || 0, new.lines.size || 0).times do |i|
    next if old.lines[i]? && old.lines[i] == new.lines[i]?
    if oline = old.lines.index { |x| x == new.lines[i]? }
      result << {i.to_i64, oline.to_i64}
    else
      result << {i.to_i64, new.lines[i]?.as(String?)}
    end
  end
  result
end

# Apply a diff generated by diff() to a string
def patch(original : String, diff : DiffType) : String
  result = [] of String?
  iterations = Math.max(original.lines.size, diff.map(&.[0]).max)
  (iterations + 1).times do |i|
    if update = diff.find { |line, _| line == i }
      if update[1].is_a? Int64
        result << original.lines[update[1].as Int64]
      else
        result << update[1].as(String?)
      end
    else
      result << original.lines[i]?
    end
  end
  result.reject(nil).join("\n")
end

def rev_text(revision)
  stack = [revision]
  parent_id : Int64? = revision.parent_revision_id
  while parent_id
    parent = DATABASE.query_all(
      "select * from doc_revisions where doc_id = ? and id = ? and not revision_diff is null",
      revision.doc_id, parent_id, as: DocRevision
    )[0]
    parent_id = parent.parent_revision_id
    stack << parent
  end

  text = ""
  stack.reverse.each do |rev|
    text = patch(text, DiffType.from_json(rev.revision_diff.not_nil!))
  end

  text
end
