# Validate WordPress Plugin "Tested Up To" Version
[![GitHub License](https://img.shields.io/github/license/jazzsequence/action-validate-plugin-version)](https://github.com/jazzsequence/action-validate-plugin-version/blob/main/LICENSE)
[![Validate Plugin Version Test](https://github.com/jazzsequence/action-validate-plugin-version/actions/workflows/test.yml/badge.svg)](https://github.com/jazzsequence/action-validate-plugin-version/actions/workflows/test.yml)

A GitHub action that validates the last tested plugin version against the current version of WordPress.

## Usage

```yaml
name: Validate Plugin Version
on:
  schedule:
    - cron: '0 0 * * 0'
permissions:
  contents: write
  pull-requests: write
  
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Validate Plugin Version
        uses: jazzsequence/action-validate-plugin-version@v1
        with:
          plugin-path: 'path/to/plugin-slug/'
          filenames: 'readme.txt,README.MD'
          branch: 'main'
```

### Configuration

Your `actions/checkout` action **must include** `fetch-depth`. `fetch-depth: 0` ensures that all branches are pulled which is _necessary_ for ensuring that the _correct branch_ is used to create the pull request against.

### Inputs

#### `plugin-path`
The path to the plugin directory to validate. If not specified, the action will use the project root.

#### `dry-run`
Only used in self-testing. If passed, this will not actually create a PR against the repository.

#### `gh-token`
The GitHub token to use for creating a PR. If not specified, the action will use the default GitHub token.

#### `filenames`
A comma-separated list of filenames to check for the "Tested Up To" version. If not specified, the action will use `readme.txt` and `README.md`.

#### `branch`
The branch to create the PR against. If not specified, the action will use the branch the workflow is running on (default branch for cron-triggered workflows).

#### `pr-status`
The status to set on the PR. If not specified, the action will create a _draft_ PR. Accepts `draft` or `open`.

## Permissions

The `write` permissions on `contents` and `pull-requests` are important. They are required for the action to commit the changes back to the repository and open a pull request. The only files affected by the action are files named `readme.txt`, `README.md` or those files matching the pattern (looking for "Tested Up To" in the file) that have been specified in the `filenames` input. 
