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
      - uses: actions/checkout@v2
      - name: Validate Plugin Version
        uses: jazzsequence/action-validate-plugin-version@v0
        with:
          plugin-path: 'path/to/plugin-slug/'
          filenames: 'readme.txt,README.MD'
          branch: 'main'
```

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
The branch to create the PR against. If not specified, the action will use the `main` branch.