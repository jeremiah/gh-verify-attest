Let's check some artifacts shall we? FWIW, the perl shasum tool I used on Debian defaults to the SHA 1 algorithm, so one has to pass the `-a 256` flag for SHA256 sums. 

```bash
$ wget https://github.com/stalwartlabs/stalwart/releases/download/v0.13.1/stalwart-x86_64-unknown-linux-gnu.tar.gz
$ shasum -a 256 stalwart-x86_64-unknown-linux-gnu.tar.gz
fc2660f8cb8d48d23fc654d70f51cbf41d8bdc512cb044e040095fa449f4b601  stalwart-x86_64-unknown-linux-gnu.tar.gz
```

The binary has different SHA256 sum (of course);

```shell
$ tar xvf stalwart-cli-x86_64-unknown-linux-gnu.tar.gz
$ shasum -a 256 stalwart
221099b91a1a7b4fba6cdd2e743cdc7ef94b99ae7fe26218aef85c76f32a1736  stalwart
```

If you want to use the attestation tooling from GitHub, which apparently is in "public preview", you can find information about it here: https://cli.github.com/manual/gh_attestation_download and download the release here: https://github.com/cli/cli/releases/tag/v2.76.1

Once I downloaded the .deb of gh and authenticated, I ran this command;

```shell
$ gh attestation verify --owner stalwartlabs stalwart-x86_64-unknown-linux-gnu.tar.gz
Loaded digest sha256:fc2660f8cb8d48d23fc654d70f51cbf41d8bdc512cb044e040095fa449f4b601 for file://stalwart-x86_64-unknown-linux-gnu.tar.gz
Loaded 1 attestation from GitHub API

The following policy criteria will be enforced:
- Predicate type must match:................ https://slsa.dev/provenance/v1
- Source Repository Owner URI must match:... https://github.com/stalwartlabs
- Subject Alternative Name must match regex: (?i)^https://github.com/stalwartlabs/
- OIDC Issuer must match:................... https://token.actions.githubusercontent.com

✓ Verification succeeded!

The following 1 attestation matched the policy criteria

- Attestation #1
  - Build repo:..... stalwartlabs/stalwart
  - Build workflow:. .github/workflows/ci.yml@refs/tags/v0.13.1
  - Signer repo:.... stalwartlabs/stalwart
  - Signer workflow: .github/workflows/ci.yml@refs/tags/v0.13.1
```

