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

# Repos with a published GitHub Pages site link to it; the repo moves to a second link.
# Probe the conventional URL rather than the Pages API, which the workflow token cannot read.
pages='{}'
for name in $(jq -r '.[] | select(.has_pages) | .name' <<<"$repos"); do
	url="https://$owner.github.io/$name/"
	if [[ $(curl -s -o /dev/null -w '%{http_code}' -L "$url") == 200 ]]; then
		pages=$(jq -c --arg n "$name" --arg u "$url" '. + {($n): $u}' <<<"$pages")
	fi
done

cards=$(jq -r --argjson pages "$pages" '.[] | ($pages[.name] // null) as $site
	| "<article class=\"card\"><h3><a href=\"\($site // .html_url)\">\(.name | @html)</a></h3>"
	+ "<p>\((.description // "No description yet." ) | @html)</p>"
	+ "<footer>\(if .language then "<span class=\"lang\">\(.language | @html)</span>" else "" end)"
	+ "\(if .stargazers_count > 0 then "<span>★ \(.stargazers_count)</span>" else "" end)"
	+ "\(if $site then "<a href=\"\(.html_url)\">GitHub</a>" else "" end)"
	+ "\(if (.homepage // "") != "" and (.homepage != $site) and (.homepage | test("^https?://")) then "<a href=\"\(.homepage | @html)\">Website</a>" else "" end)"
	+ "<span class=\"when\">Updated \(.pushed_at[:10])</span></footer></article>"' <<<"$repos")

count=$(jq length <<<"$repos")
shopt -u patsub_replacement 2>/dev/null || true # bash 5.2: & in a replacement means the match
page=$(<template.html)
page=${page//@COUNT@/$count}
page=${page//@CARDS@/$cards}
printf '%s\n' "$page" >_site/index.html
echo "Built _site/index.html with $count repositories"
