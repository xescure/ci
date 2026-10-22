# xescure/ci

Shared CI for xescure's Nix projects.

## `nix-image.yml`

A reusable workflow that builds a flake's checks and OCI images in **one job**,
on one restored Nix store, so the images reuse every derivation the checks built.

```yaml
jobs:
  build:
    uses: xescure/ci/.github/workflows/nix-image.yml@<commit sha>
    with:
      checks: lint typecheck        # names under checks.<system>; empty skips
      images: image                 # flake attributes of the images
      lockfiles: package-lock.json  # keys the Nix cache, besides flake.lock
      integration: ""               # a command run outside the sandbox (network tests)
      bwrap: false                  # lift Ubuntu's userns restriction for bwrap checks
```

The job installs Nix with `cachix/install-nix-action` and caches `/nix` with
`nix-community/cache-nix-action`, keyed on `flake.lock` plus `lockfiles`. The
run page summarises each check, image and integration step with its time.

Project-specific checks belong in the project's flake as `checks.<system>.<name>`.
An input is added here only when a second project needs the same runner-level
quirk. A project needing more than two such quirks writes its own job.

Callers pin this repository by commit. This repository's own flake checks are the
workflow's self-test (`self-test.yml`).
