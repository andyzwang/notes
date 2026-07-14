# frozen_string_literal: true

require 'open3'

module Recents
  # Runs as a Jekyll Generator (during the `site.generate` phase, which is
  # after the jekyll-last-modified-at gem's :post_init hook has already set
  # each doc's `last_modified_at`). We recompute the "Last updated on" date
  # ourselves so we can IGNORE structural commits — bulk edits (e.g. a link-
  # syntax migration) that touch every note but aren't real content changes.
  #
  # Mark such a commit by putting a token in its message (default
  # "[structure]"); the date then reflects the most recent commit that
  # touched the file and is NOT so tagged. Configure the token in _config.yml:
  #
  #   last-modified-at:
  #     ignore-commits-matching: "[structure]"
  #
  # Requires full git history at build time (the CI checkout uses
  # fetch-depth: 0, so this holds).
  class Generator < Jekyll::Generator
    priority :low

    def generate(site)
      marker = site.config.dig('last-modified-at', 'ignore-commits-matching') || '[structure]'

      site.collections['notes'].docs.each do |page|
        time = last_modified_time(site.source, page.path, marker)
        next unless time

        # `last_modified_at` (a Time) drives the displayed date; the ISO
        # string in `last_modified_at_timestamp` is the sort key used by the
        # "Recent Notes" list on the home page (lexical sort == chronological).
        page.data['last_modified_at'] = time
        page.data['last_modified_at_timestamp'] = time.strftime('%FT%T%:z')
      end
    end

    private

    # Most recent commit touching `rel_path` whose message does NOT contain
    # `marker`. Falls back to the latest commit of any kind, then to the file's
    # mtime, so a never-committed or only-structurally-touched file still dates.
    def last_modified_time(source, rel_path, marker)
      unix = git_log_unix(source, rel_path, marker) || git_log_unix(source, rel_path, nil)
      return Time.at(unix.to_i) if unix

      abs = File.join(source, rel_path)
      File.exist?(abs) ? File.mtime(abs) : nil
    end

    # Returns the committer unix timestamp of the newest matching commit, or
    # nil if there is none / git is unavailable. When `marker` is given, the
    # match is inverted: commits whose message contains it are skipped.
    def git_log_unix(source, rel_path, marker)
      args = ['git', 'log', '-n', '1', '--format=%ct']
      args += ['--fixed-strings', '--invert-grep', "--grep=#{marker}"] if marker
      args += ['--', rel_path]

      out, status = Open3.capture2(*args, chdir: source)
      return nil unless status.success?

      stamp = out[/\d+/]
      stamp&.empty? ? nil : stamp
    rescue StandardError
      nil
    end
  end
end
