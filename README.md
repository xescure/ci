# xescure/ci

Pin by commit.

## `nix-image.yml`

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, closed]
  push:
    branches: [main]
  schedule:
    - cron: "17 4 * * 1"   # the Nix cache expires after 7 days unused

# A merged pull request's closed run has the base branch as its ref.
concurrency:
  group: ci-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  build:
    if: github.event.action != 'closed'
    permissions:
      contents: read
      packages: write
    uses: xescure/ci/.github/workflows/nix-image.yml@<sha>
    with:
      checks: lint typecheck
      images: image
      lockfiles: package-lock.json
      integration: ""
      bwrap: false

  pr-images:
    if: github.event.action == 'closed'
    permissions:
      contents: read
      packages: write
    uses: xescure/ci/.github/workflows/pr-images.yml@<sha>
    with:
      images: image
```

| Event | Tags |
|---|---|
| push to the default branch | `sha-<commit>`, `main` |
| pull request from this repository | `pr-<n>`, `pr-<n>-<head sha7>` |
| `v*` release | `v<version>`, `latest`, and the `prod` branch |

Set artifact retention to 400 days so old commits stay releasable.

## Releases

```yaml
on:
  push:
    tags: ["v*"]

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      actions: read
      packages: write
    steps:
      - uses: actions/checkout@<sha>
        with:
          persist-credentials: false
      - uses: cachix/install-nix-action@<sha>
      - id: release
        uses: xescure/ci/.github/actions/release-images@<sha>
        with:
          test-job: deploy-test   # "" when there is no deploy to test
      - uses: xescure/ci/.github/actions/tag-images@<sha>
        with:
          images: ${{ steps.release.outputs.images }}
          tags: ${{ github.ref_name }} latest
      - uses: xescure/ci/.github/actions/prod-branch@<sha>
        with:
          commit: ${{ steps.release.outputs.commit }}
      - run: deploy prod "${{ fromJSON(steps.release.outputs.images)['image'] }}"
```

The release publishes before the project's own deploy, which is one consumer
among others. Rolling back means re-running an older release's run. Without images, keep
`release-images` and `prod-branch`.

## Renovate

```json
{ "extends": ["local>xescure/ci"] }
```
