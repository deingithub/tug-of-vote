require "db"
require "base64"
require "sqlite3"
require "json"

def read_list(str)
  str.split(",").map { |x| Base64.decode_string(x) }
end

def read_assoc(str)
  str.split(",").map { |x|
    kv = x.split(":")
    {Base64.decode_string(kv[0]), Base64.decode_string(kv[1]).to_i}
  }.to_h
end

# this is a very braindead way to migrate a database, but what else can one do

DB.open "sqlite3:./tugofvote.db" do |db|
  db.transaction do |trans|
    c = trans.connection

    # polls, lists, caps, votes, docs, doc_users, doc_revisions, doc_revision_reactions:
    # use data type "text" because "string" isn't actually a real type and causes issues
    <<-SQL.split(";", remove_empty: true).map { |s| x = s.strip; puts x; c.exec(x) }
    create table polls_2 (
      id integer primary key,
      created_at date default current_timestamp,
      title text not null,
      description text not null,
      duration integer default null
    );
    insert into polls_2 select * from polls where true;
    drop table polls;
    alter table polls_2 rename to polls;

    create table lists_2 (
      id integer primary key,
      created_at date default current_timestamp,
      description text not null,
      title text not null,
      webhook_url text not null default ""
    );
    insert into lists_2 select * from lists where true;
    drop table lists;
    alter table lists_2 rename to lists;

    create table caps_2 (
      cap_slug text primary key,
      kind integer not null,
      poll_id integer,
      list_id integer,
      ballot_id integer,
      doc_id integer,
      foreign key (poll_id) references polls(id),
      foreign key (list_id) references lists(id),
      foreign key (ballot_id) references ballots(id),
      foreign key (doc_id) references docs(id),
      constraint "Exactly one foreign key" check (
        (not poll_id is null and list_id is null and ballot_id is null and doc_id is null) or
        (poll_id is null and not list_id is null and ballot_id is null and doc_id is null) or
        (poll_id is null and list_id is null and not ballot_id is null and doc_id is null) or
        (poll_id is null and list_id is null and ballot_id is null and not doc_id is null)
      )
    );
    insert into caps_2 select * from caps where true;
    drop table caps;
    alter table caps_2 rename to caps;

    create table votes_2 (
      kind integer not null,
      username text not null,
      password text not null,
      created_at date default current_timestamp,
      reason text,
      poll_id integer not null,
      foreign key (poll_id) references polls(id)
    );
    insert into votes_2 select * from votes where true;
    drop table votes;
    alter table votes_2 rename to votes;

    create table docs_2 (
      id integer primary key,
      created_at date default current_timestamp,
      title text not null
    );
    insert into docs_2 select * from docs where true;
    drop table docs;
    alter table docs_2 rename to docs;

    create table doc_users_2 (
      doc_id integer not null,
      username text not null,
      password text not null,
      foreign key (doc_id) references docs(id),
      constraint "unique usernames" unique(doc_id, username)
    );
    insert into doc_users_2 select * from doc_users where true;
    drop table doc_users;
    alter table doc_users_2 rename to doc_users;

    create table doc_revisions_2 (
      id integer not null,
      doc_id integer not null,
      created_at date default current_timestamp,
      username text not null,
      comment text not null,
      revision_diff text,
      parent_revision_id integer,
      foreign key (doc_id) references docs(id),
      foreign key (doc_id, parent_revision_id) references doc_revisions(doc_id, id),
      foreign key (doc_id, username) references doc_users(doc_id, username),
      constraint "unique revision ids" unique(doc_id, id)
    );
    insert into doc_revisions_2 select * from doc_revisions where true;
    drop table doc_revisions;
    alter table doc_revisions_2 rename to doc_revisions;


    create table doc_revision_reactions_2 (
      doc_id integer not null,
      revision_id integer not null,
      username text not null,
      kind integer not null,
      foreign key(doc_id, revision_id) references doc_revisions(doc_id, id),
      foreign key(doc_id, username) references doc_users(doc_id, username)
    );
    insert into doc_revision_reactions_2 select * from doc_revision_reactions where true;
    drop table doc_revision_reactions;
    alter table doc_revision_reactions_2 rename to doc_revision_reactions;
    SQL

    <<-SQL.split(";", remove_empty: true).map { |s| x = s.strip; puts x; c.exec(x) }
    create table ballots_2 (
      id integer primary key,
      created_at date default current_timestamp,
      title text not null,
      candidates text not null,
      duration integer default null,
      cached_result text not null,
      hide_names bool not null
    );
    SQL

    c.query_each("select * from ballots") do |row|
      id, created_at, title, candidates, duration, cached_result, hide_names = row.read(Int64), row.read.to_s, row.read.to_s, row.read.to_s, row.read(Int64?), row.read.to_s, row.read(Bool)

      candidates = read_list(candidates).sort
      cached_result = read_assoc(cached_result).transform_keys { |k| candidates.index(k) }

      c.exec(
        "insert into ballots_2 values(?,?,?,?,?,?,?)",
        id, created_at, title, candidates.to_json, duration, cached_result.to_json, hide_names
      )
    end

    <<-SQL.split(";", remove_empty: true).map { |s| x = s.strip; puts x; c.exec(x) }
    drop table ballots;
    alter table ballots_2 rename to ballots;
    SQL

    c.exec(<<-SQL)
    create table ballot_votes_2 (
      ballot_id integer not null,
      created_at date default current_timestamp,
      username text not null,
      password text not null,
      preferences text not null,
      foreign key (ballot_id) references ballots(id)
    );
    SQL

    c.query_each("select * from ballot_votes") do |row|
      ballot_id, created_at, username, password, preferences = row.read(Int64), row.read.to_s, row.read.to_s, row.read.to_s, row.read.to_s

      preferences = read_assoc(preferences)
      candidates = c.query_one("select candidates from ballots where id = ?", ballot_id, as: String)
      candidates = Array(String).from_json(candidates)
      c.exec(
        "insert into ballot_votes_2 values(?,?,?,?,?)",
        ballot_id, created_at, username, password, preferences.transform_keys { |k| candidates.index(k) }.to_json
      )
    end

    <<-SQL.split(";", remove_empty: true).map { |s| x = s.strip; puts x; c.exec(x) }
    drop table ballot_votes;
    alter table ballot_votes_2 rename to ballot_votes;
    SQL

    c.exec("PRAGMA foreign_key_check")
    puts "should be ok"
  end
  db.exec("VACUUM")
end
