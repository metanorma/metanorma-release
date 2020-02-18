# Helpers for *.adoc.erb

def github_link(org, repo)
  %Q(https://github.com/#{org}/#{repo}[#{repo}])
end

def shield_code_climate(org, repo)
  shield_url = "https://codeclimate.com/github/#{org}/#{repo}/badges/gpa.svg"
  shield_link = "https://codeclimate.com/github/#{org}/#{repo}"
  shield_alt_text = "Code Climate"

  shield(shield_url, alt: shield_alt_text, link: shield_link)
end

def shield_commits_since(org, repo)
  shield_url =
    "https://img.shields.io/github/commits-since/#{org}/#{repo}/latest.svg"
  shield_link = "https://github.com/#{org}/#{repo}/releases"
  shield_alt_text = "Commits since latest"

  shield(shield_url, alt: shield_alt_text, link: shield_link)
end

def shield_gem(name)
  shield_url = "https://img.shields.io/gem/v/#{name}.svg"
  shield_link = "https://rubygems.org/gems/#{name}"
  shield_alt_text = "Gem Version"

  shield(shield_url, alt: shield_alt_text, link: shield_link)
end

def shield_gha_macos(org, repo)
  shield_url = "https://github.com/#{org}/#{repo}/workflows/macos/badge.svg"
  shield_link = "https://github.com/#{org}/#{repo}/actions?workflow=macos"
  shield_alt_text = "Build Status (macOS)"

  shield(shield_url, alt: shield_alt_text, link: shield_link)
end

def shield_gha_ubuntu(org, repo)
  shield_url = "https://github.com/#{org}/#{repo}/workflows/ubuntu/badge.svg"
  shield_link = "https://github.com/#{org}/#{repo}/actions?workflow=ubuntu"
  shield_alt_text = "Build Status (Ubuntu)"

  shield(shield_url, alt: shield_alt_text, link: shield_link)
end

def shield_gha_windows(org, repo)
  shield_url = "https://github.com/#{org}/#{repo}/workflows/windows/badge.svg"
  shield_link = "https://github.com/#{org}/#{repo}/actions?workflow=windows"
  shield_alt_text = "Build Status (Windows)"

  shield(shield_url, alt: shield_alt_text, link: shield_link)
end

def shield_pull_requests(org, repo)
  shield_url = "https://img.shields.io/github/issues-pr-raw/#{org}/#{repo}.svg"
  shield_link = "https://github.com/#{org}/#{repo}/pulls"
  shield_alt_text = "Pull Requests"

  shield(shield_url, alt: shield_alt_text, link: shield_link)
end

def shield(img, link:, alt:)
  %Q(image:#{img}["#{alt}",link="#{link}"])
end
