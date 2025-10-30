#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

main() {
	if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
		DEFAULT_BRANCH="${GITHUB_BASE_REF}"
	else
		DEFAULT_BRANCH=$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5)
	fi
	echo "Default branch is $DEFAULT_BRANCH"

	# Check out the specified branch if $BRANCH is set and not already on it
	if [[ -z "${GITHUB_BASE_REF:-}" && -n "${BRANCH:-}" && "$(git rev-parse --abbrev-ref HEAD)" != "$BRANCH" ]]; then
		echo "Checking if branch $BRANCH exists."
		if ! git show-ref --verify --quiet "refs/heads/$BRANCH"; then
			if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
				echo "Branch '$BRANCH' exists on remote. Checking out from remote."
				git checkout -b "$BRANCH" "origin/$BRANCH"
			else
				echo "Error: Branch '$BRANCH' does not exist."
				exit 1
			fi
		else
			echo "Checking out branch $BRANCH"
			git checkout "$BRANCH"
		fi
	fi

	# If $PLUGIN_PATH is defined, echo it.
	if [[ -n "${PLUGIN_PATH:-}" ]]; then
		 PLUGIN_PATH=${WORKFLOW_PATH}/${PLUGIN_PATH}
		echo "Plugin path: $PLUGIN_PATH"
	else
		local PLUGIN_PATH
		# By default, the plugin path is the root directory of the project that has this action.
		PLUGIN_PATH=$WORKFLOW_PATH
		echo "Plugin path: $PLUGIN_PATH"
	fi

	# Check if the plugin path exists.
	if [[ ! -d "${PLUGIN_PATH}" ]]; then
		echo "Plugin path does not exist."
		exit 1
	fi

	local CURRENT_WP_VERSION
	CURRENT_WP_VERSION=$(curl -s https://api.wordpress.org/core/version-check/1.7/ | jq -r '.offers[0].current')
	echo "Current WordPress Version: ${CURRENT_WP_VERSION}"

	# Adjust version based on validation level
	case "${VALIDATION_LEVEL:-minor}" in
		minor)
			CURRENT_WP_VERSION=$(echo "$CURRENT_WP_VERSION" | cut -d'.' -f1,2)
			echo "Validation level is 'minor', using WordPress version: ${CURRENT_WP_VERSION}"
			;;
		patch)
			echo "Validation level is 'patch', using full WordPress version: ${CURRENT_WP_VERSION}"
			;;
		*)
			echo "Error: Invalid validation-level specified: ${VALIDATION_LEVEL}. Must be 'minor' or 'patch'."
			exit 1
			;;
	esac

	# Split FILENAMES into an array
	IFS=',' read -ra FILENAMES_ARRAY <<< "$FILENAMES"

	local TESTED_UP_TO=""
	for filename in "${FILENAMES_ARRAY[@]}"; do
		trimmed_filename=$(echo "$filename" | xargs) # Trim whitespace
		full_path="${PLUGIN_PATH}/${trimmed_filename}"

		# Get "Tested up to" version if file exists
		if [[ -f "$full_path" ]]; then
			TESTED_UP_TO=$(grep -i "Tested up to:" "$full_path" | tr -d '\r\n' | awk -F ': ' '{ print $2 }')
			echo "Found 'Tested up to' version in $trimmed_filename: $TESTED_UP_TO"
			break
		fi
	done

	if [[ -z "$TESTED_UP_TO" ]]; then
		echo "'Tested up to' version not found in any of the specified files: ${FILENAMES_ARRAY[*]}"
		exit 1
	fi
	
	# Compare versions using PHP
	if php -r "exit(version_compare('$TESTED_UP_TO', '$CURRENT_WP_VERSION', '>=') ? 0 : 1);"; then
		echo "Tested up to version matches or is greater than the current WordPress version. Check passed."
		exit
	fi
	echo "Tested up to version ($TESTED_UP_TO) is less than current WordPress version ($CURRENT_WP_VERSION)."
	echo "Updating files with new Tested up to version."

	# Update each specified filename if it exists
	for filename in "${FILENAMES_ARRAY[@]}"; do
		trimmed_filename=$(echo "$filename" | xargs) # Trim whitespace
		full_path="${PLUGIN_PATH}/${trimmed_filename}"

		if [[ -f "$full_path" ]]; then
			echo "Updating 'Tested up to' version in $full_path"
			if [[ "$OSTYPE" == "darwin"* ]]; then
				sed -i '' -E "s/(Tested up to: )([0-9.]+)([[:space:]]*)/\1$CURRENT_WP_VERSION\3/" "$full_path"
			else
				sed -i -E "s/(Tested up to: )([0-9.]+)([[:space:]]*)/\1$CURRENT_WP_VERSION\3/" "$full_path"
			fi
		fi
	done

	# Create a pull request with a dynamic branch name
	BRANCH_PREFIX="update-tested-up-to-version-"
	BRANCH_NAME="${BRANCH_PREFIX}$(date +%Y%m%d%H%M%S)"


    # All PRs open on the repo. Ones created by this action will have a known branch name.
	local OPEN_PRS
	OPEN_PRS=$(gh pr list --state open --json number,headRefName)

	# Check for exact match and exit if found
	local EXACT_MATCH_PR_ID
	EXACT_MATCH_PR_ID=$(echo "$OPEN_PRS" | jq -r --arg exact "$BRANCH_NAME" '.[] | select(.headRefName == $exact) | .number')
	if [[ -n "$EXACT_MATCH_PR_ID" ]]; then
		echo "❌ A PR already exists for branch '$BRANCH_NAME': #$EXACT_MATCH_PR_ID"
		exit 0
	fi


	echo "Creating a new branch $BRANCH_NAME and pushing changes."
	git config user.name "github-actions"
	git config user.email "github-actions@github.com"
	git checkout -b "$BRANCH_NAME"

	# Add updated files to git
	for filename in "${FILENAMES_ARRAY[@]}"; do
		trimmed_filename=$(echo "$filename" | xargs) # Trim whitespace
		full_path="${PLUGIN_PATH}/${trimmed_filename}"
		if [[ -f "$full_path" ]]; then
			git add "$full_path"
			# If we're dry-running, output the contents of the changed files.
			if [[ "${DRY_RUN}" == "true" ]]; then
				echo -e "\n"
				cat "$full_path"
			fi
		fi
	done

	# Bail before committing anything if we're dry-running.
	if [[ "${DRY_RUN}" == "true" ]]; then
		echo "Dry run enabled. Happy testing."
		exit 0
	fi

	# Check if there are any staged changes
	if [[ -z $(git status --porcelain) ]]; then
		echo "No changes to commit. Exiting."
		exit 1
	fi

	echo "Committing changes and pushing to the repository."
	git commit -m "Update Tested Up To version to $CURRENT_WP_VERSION"
	git push origin "$BRANCH_NAME"

	# Determine the base branch for the PR
	BASE_BRANCH="${BRANCH:-$DEFAULT_BRANCH}"

	echo "Creating a pull request with base branch $BASE_BRANCH."
	PR_OPTIONS=(
		--title "Update Tested Up To version to $CURRENT_WP_VERSION"
		--body "This pull request updates the 'Tested up to' version in specified files (${FILENAMES}) to match the current WordPress version $CURRENT_WP_VERSION."
		--base "$BASE_BRANCH"
	)

	if [[ "${PR_STATUS:-}" != "open" ]]; then
		PR_OPTIONS+=(--draft)
	fi

	NEW_PR_URL=$(gh pr create "${PR_OPTIONS[@]}")

	local PREFIX_MATCHES
	PREFIX_MATCHES=$(echo "$OPEN_PRS" | jq -r --arg prefix "$BRANCH_PREFIX" '.[] | select(.headRefName | startswith($prefix)) | "\(.number) \(.headRefName)"')
	while read -r pr_line; do
		if [[ -z "$pr_line" ]]; then
			continue
		fi
		local pr_number
		pr_number=$(echo "$pr_line" | awk '{print $1}')
		local pr_branch
		pr_branch=$(echo "$pr_line" | awk '{print $2}')
		echo "🛑 Closing old PR #$pr_number from branch '$pr_branch'"
		gh pr close "$pr_number" --comment "Superseded by $NEW_PR_URL"
	done <<< "$PREFIX_MATCHES"
}

main