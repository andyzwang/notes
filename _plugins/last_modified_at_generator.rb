# frozen_string_literal: true

require 'open3'

module Recents
  # Runs as a Jekyll Generator (during the `site.generate` phase, which is
  # after the jekyll-last-modified-at gem's :post_init hook has already set
  # each doc's `last_modified_at`). We recompute the "Last updated on" date
  # ourselves so we can IGNORE structural commits — bulk edits (e.g. a link-
  # syntax migration) that touch every note but aren't real content changes.
  #
  # A commit is ignored if EITHER:
  #   * its message contains the marker token (default "[structure]"), or
  #   * its SHA is listed in ignore-commits (for pre-convention commits that
  #     can't be re-tagged without rewriting history).
  # The date then reflects the most recent commit touching the file that is
  # NOT ignored. Configure both in _config.yml:
  #
  #   last-modified-at:
  #     ignore-commits-matching: "[structure]"
  #     ignore-commits:
  #       - bb2d80a
  #
  # Requires full git history at build time (the CI checkout uses
  # fetch-depth: 0, so this holds).
  class Generator < Jekyll::Generator
    priority :low

    def generate(site)
      cfg = site.config['last-modified-at'] || {}
      marker = cfg['ignore-commits-matching'] || '[structure]'
      ignored = Array(cfg['ignore-commits']).map { |s| s.to_s.strip }.reject(&:empty?)

      site.collections['notes'].docs.each do |page|
        time = last_modified_time(site.source, page.path, marker, ignored)
        next unless time

        # `last_modified_at` (a Time) drives the displayed date; the ISO
        # string in `last_modified_at_timestamp` is the sort key used by the
        # "Recent Notes" list on the home page (lexical sort == chronological).
        page.data['last_modified_at'] = time
        page.data['last_modified_at_timestamp'] = time.strftime('%FT%T%:z')
      end
    end

    private

    # Most recent commit touching `rel_path` that is neither message-marked nor
    # SHA-ignored. Falls back to the latest commit of any kind, then to the
    # file's mtime, so a never-committed or wholly-ignored file still dates.
    def last_modified_time(source, rel_path, marker, ignored)
      commits = git_log_commits(source, rel_path, marker)
                .reject { |sha, _| ignored_sha?(sha, ignored) }
      commits = git_log_commits(source, rel_path, nil) if commits.empty?

      return Time.at(commits.first[1].to_i) unless commits.empty?

      abs = File.join(source, rel_path)
      File.exist?(abs) ? File.mtime(abs) : nil
    end

    def ignored_sha?(sha, ignored)
      ignored.any? { |prefix| sha.start_with?(prefix) }
    end

    # [[sha, unix_committer_date], ...] for commits touching rel_path, newest
    # first. When `marker` is given, commits whose message contains it are
    # skipped by git itself. Empty on error / no git.
    def git_log_commits(source, rel_path, marker)
      args = ['git', 'log', '--format=%H %ct']
      args += ['--fixed-strings', '--invert-grep', "--grep=#{marker}"] if marker
      args += ['--', rel_path]

      out, status = Open3.capture2(*args, chdir: source)
      return [] unless status.success?

      out.lines.filter_map do |line|
        sha, ct = line.split(' ', 2)
        ct = ct.to_s.strip
        [sha, ct] unless sha.to_s.empty? || ct.empty?
      end
    rescue StandardError
      []
    end
  end
end
