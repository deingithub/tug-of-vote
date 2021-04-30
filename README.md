# TugOfVote

The Swiss Army Knife of collaboration tools good enough for the job. To install, you need [The Nix Package Manager](https://nixos.org).

## Self-hosting Quickstart

```sh
# clone the repository and go to the folder
git clone https://github.com/deingithub/tug-of-vote
cd tug-of-vote
# prepare database
nix-shell --run "sqlite3 tov.db '.read schema.sql'"
# adjust configuration, save as 'tov.config'
$EDITOR tov.config.example
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
