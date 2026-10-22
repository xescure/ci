# xescure/ci

Shared CI for xescure's Nix projects. Callers pin it by commit.

## `nix-image.yml`: build, check and push

Builds a flake's checks and nix2container images in **one job**, on one
restored Nix store, so the images reuse every derivation the checks built.
Then it pushes the images.

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, closed]
  push:
    branches: [main]
  schedule:
    - cron: "17 4 * * 1"   # weekly: keeps main's Nix cache from expiring (7 days unused)

# A merged pull request's "closed" run has the base branch as its ref: group
# pull request runs by number, or it cancels main's push run.
concurrency:
  group: ci-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  build:
    if: github.event.action != 'closed'
    permissions:
      contents: read
      packages: write
    uses: xescure/ci/.github/workflows/nix-image.yml@<commit sha>
    with:
      checks: lint typecheck        # names under checks.<system>; empty skips
      images: image                 # flake attributes of nix2container images
      lockfiles: package-lock.json  # keys the Nix cache, besides flake.lock
      integration: ""               # a command run outside the sandbox (network tests)
      bwrap: false                  # lift Ubuntu's userns restriction for bwrap checks

  pr-images:
    if: github.event.action == 'closed'
    permissions:
      contents: read
      packages: write
    uses: xescure/ci/.github/workflows/pr-images.yml@<commit sha>
    with:
      images: image
```

- **Nix:** `cachix/install-nix-action`, with `/nix` cached by
  `nix-community/cache-nix-action`, keyed on `flake.lock` plus `lockfiles`.
  Only main saves the cache; pull requests restore main's.
- **Push:** each image goes to the name its flake gives it (`imageName`), with
  its own `copyTo`, so only layers the registry lacks are uploaded.

  | Event | Tags |
  |---|---|
  | push to main | `sha-<commit>`, `main` |
  | pull request from this repository | `pr-<n>`, `pr-<n>-<head sha7>` |
  | release (see below) | `v<version>`, `latest` |
  | anything else (forks, schedule) | none |

- **Output:** `images`, a JSON object from flake attribute to `name@digest`,
  e.g. `fromJSON(needs.build.outputs.images)['image']` for a deploy job. On
  main the same object is saved as the run's `image-digests` artifact
  (raise the repository's artifact retention to 400 days so old commits stay
  releasable).
- **Token:** the checkout keeps no credentials, and only the push step sees
  the token that can write packages.
- The run page summarises each check, image, integration step and push.

## `pr-images.yml`: clean up a closed pull request's images

Deletes the package versions whose tags are all `pr-<n>…`. A version main also
tagged stays (reproducible builds often give the merged code the same digest).

## Releases: `release-images` and `tag-images`

A `v*` tag promotes what main built, never a rebuild and never a registry tag
(any workflow that can write packages can move a tag):

```yaml
on:
  push:
    tags: ["v*"]

jobs:
  deploy-prod:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      actions: read
      packages: write
    steps:
      - uses: actions/checkout@<sha>
        with:
          persist-credentials: false
      - uses: cachix/install-nix-action@<sha>
      # The tag must be on main, and main's CI run for it must have succeeded
      # and deployed to test; the digests come from that run's artifact.
      - id: release
        uses: xescure/ci/.github/actions/release-images@<commit sha>
      - run: deploy prod "${{ fromJSON(steps.release.outputs.images)['image'] }}"
      # Once prod runs it.
      - uses: xescure/ci/.github/actions/tag-images@<commit sha>
        with:
          images: ${{ steps.release.outputs.images }}
          tags: ${{ github.ref_name }} latest
```

## Conventions

Project-specific checks belong in the project's flake as `checks.<system>.<name>`.
An input is added here only when a second project needs the same runner-level
quirk. A project needing more than two such quirks writes its own job.

This repository's flake is the self-test (`self-test.yml`): its checks exercise
the inputs, and its fixture image is pushed to `ghcr.io/xescure/ci-fixture`.

## Renovate preset (`default.json`)

Projects extend it with a `renovate.json` of one line (the hosted Renovate app
must be installed on this repository too, to read it):

```json
{ "extends": ["local>xescure/ci"] }
```

- Weekly (Monday before 6am UTC), one grouped PR per ecosystem: Rust, npm,
  GitHub Actions, Nix flake inputs, plus lock file maintenance.
- npm and crates releases wait 3 days before they are proposed; security fixes
  come at any time.
- Green minor, patch, digest and lock file updates merge themselves (main
  deploys to test; prod still needs a `v*` tag). Majors, and anything below
  1.0, wait for review.
- The `xescure/ci` pin follows main by digest: its own PR as soon as main moves.
