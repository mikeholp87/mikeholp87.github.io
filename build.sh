#!/usr/bin/env bash
# Build _site/index.html from the owner's PUBLIC repositories.
# /users/<owner>/repos only ever returns public repos, so private ones cannot leak.
set -euo pipefail
cd -- "$(dirname -- "$0")"

owner=${OWNER:-mikeholp87}
mkdir -p _site
repos=$(gh api --paginate "users/$owner/repos?per_page=100&sort=pushed" |
	jq -s --arg self "$owner.github.io" '
		add | map(select(.fork == false and .archived == false and .name != $self))
		| sort_by(.pushed_at) | reverse')

cards=$(jq -r '.[] | "<article class=\"card\"><h3><a href=\"\(.html_url)\">\(.name | @html)</a></h3>"
	+ "<p>\((.description // "No description yet." ) | @html)</p>"
	+ "<footer>\(if .language then "<span class=\"lang\">\(.language | @html)</span>" else "" end)"
	+ "\(if .stargazers_count > 0 then "<span>★ \(.stargazers_count)</span>" else "" end)"
	+ "\(if (.homepage // "") != "" and (.homepage | test("^https?://")) then "<a href=\"\(.homepage | @html)\">Website</a>" else "" end)"
	+ "<span class=\"when\">Updated \(.pushed_at[:10])</span></footer></article>"' <<<"$repos")

count=$(jq length <<<"$repos")
shopt -u patsub_replacement 2>/dev/null || true # bash 5.2: & in a replacement means the match
page=$(<template.html)
page=${page//@COUNT@/$count}
page=${page//@CARDS@/$cards}
printf '%s\n' "$page" >_site/index.html
echo "Built _site/index.html with $count repositories"
