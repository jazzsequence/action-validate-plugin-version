#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

main(){

    local CURRENT_WP_VERSION
    CURRENT_WP_VERSION=$(curl -s https://api.wordpress.org/core/version-check/1.7/ | jq -r '.offers[0].current')
    echo "Current WordPress Version: ${CURRENT_WP_VERSION}"

	# Get "Tested up to" version from readme.txt
	if [[ -f "readme.txt" ]]; then
		TESTED_UP_TO=$(grep -i "Tested up to:" readme.txt | tr -d '\r\n' | awk -F ': ' '{ print $2 }')
	else
		echo "readme.txt not found."
		exit 1
	fi

	if [[ -z "$TESTED_UP_TO" ]]; then
		echo "Tested up to version not found in readme.txt."
		exit 1
	fi

	# Compare versions using PHP
	COMPARE_VERSIONS=$(php -r "echo version_compare('$TESTED_UP_TO', '$CURRENT_WP_VERSION');")
	echo "Comparison result: $COMPARE_VERSIONS"
	
	if [[ $COMPARE_VERSIONS -eq -1 ]]; then
	echo "Tested up to version ($TESTED_UP_TO) is less than current WordPress version ($CURRENT_WP_VERSION)."
	echo "Updating readme.txt with new Tested up to version."
	sed -i '' -E "s/(Tested up to: ).*/\1$CURRENT_WP_VERSION/" readme.txt

	# Update README.md if it exists
	if [[ -f "README.md" ]]; then
		sed -i '' -E "s/(Tested up to: ).*/\1$CURRENT_WP_VERSION/" README.md
		echo "README.md updated with new Tested up to version."
	fi

	# Create a pull request with a dynamic branch name
	BRANCH_PREFIX="update-tested-up-to-version-"
	BRANCH_NAME="$BRANCH_PREFIX$(date +%Y%m%d%H%M%S)"
	if git ls-remote --heads origin | grep -q "$BRANCH_PREFIX"; then
		echo "A branch with prefix $BRANCH_PREFIX already exists. Exiting."
		exit 1
	fi

	git config user.name "github-actions"
	git config user.email "github-actions@github.com"
	git checkout -b "$BRANCH_NAME"
	git add readme.txt README.md || true
	git commit -m "Update Tested Up To version to $CURRENT_WP_VERSION"
	git push origin "$BRANCH_NAME"

	gh pr create --title "Update Tested Up To version to $CURRENT_WP_VERSION" --body "This pull request updates the \"Tested up to\" version in readme.txt (and README.md if applicable) to match the current WordPress version $CURRENT_WP_VERSION."
	else
	echo "Tested up to version matches or is greater than the current WordPress version. Check passed."
	fi
}

main