# Tug of Vote

The Swiss Army Knife of collaboration tools good enough for the job. To install, you need [The Nix Package Manager](https://nixos.org).

## Self-hosting Quickstart

```sh
# clone the repository and go to the folder
git clone https://github.com/deingithub/tug-of-vote
cd tug-of-vote
# prepare database
nix-shell --run "sqlite3 tov.db '.read schema.sql'"
# adjust configuration, save as '.env'
$EDITOR example.env
# build ToV
nix build
# run it - this path will stay the same every time you pull in and install
# a new version and can be used with e.g. systemd to run ToV as a service
./result/bin/TugOfVote
```

## Contributing

1. Fork it (<https://github.com/deingithub/tug-of-vote/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [deing](https://github.com/deingithub) - creator and maintainer

---

Copyright 2021 Cassidy Dingenskirchen

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.
