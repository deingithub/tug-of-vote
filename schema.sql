create table if not exists polls (
  id integer primary key,
  created_at date default current_timestamp,
  content string not null
);

create table if not exists caps (
  cap_slug string primary key,
  kind integer not null,
  poll_id integer not null,
  foreign key (poll_id) references polls(id)
);

create table if not exists votes (
  kind integer not null,
  username string not null,
  password string not null,
  created_at date default current_timestamp,
  reason string,
  poll_id integer not null,
  foreign key (poll_id) references polls(id)
);
