# frozen_string_literal: true

require 'open3'

module Recents
  # Runs as a Jekyll Generator (during the `site.generate` phase, which is
  # after the jekyll-last-modified-at gem's :post_init hook has already set
  # each doc's `last_modified_at`). We recompute the "Last updated on" date
  # ourselves so we can IGNORE structural commits — bulk edits (e.g. a link-
  # syntax migration, or moving/renaming the file) that touch every note but
  # aren't real content changes.
  #
  # A commit is ignored if EITHER:
  #   * its message contains the marker token (default "[structure]"), or
  #   * its SHA is listed in ignore-commits (for pre-convention commits that
  #     can't be re-tagged without rewriting history).
  # The date then reflects the most recent commit touching the file — tracing
  # through renames, so moving a note into a folder doesn't reset its date —
  # that is NOT ignored. Configure both in _config.yml:
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

      # Notes, plus the standalone hero pages (about / passages / the-canon)
      # that share the note hero and so display the same "Updated on" date.
      hero_pages = site.pages.select { |p| p.data['layout'] == 'page-hero' }
      (site.collections['notes'].docs + hero_pages).each do |page|
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

    # Most recent commit touching `rel_path` (tracing renames — see
    # git_log_commits) that is neither message-marked nor SHA-ignored. Falls
    # back to the latest commit of any kind, then to the file's mtime, so a
    # never-committed or wholly-ignored file still dates.
    def last_modified_time(source, rel_path, marker, ignored)
      commits = git_log_commits(source, rel_path)
      kept = commits.reject { |sha, _, subject| ignored_sha?(sha, ignored) || marked?(subject, marker) }
      chosen = kept.first || commits.first

      return Time.at(chosen[1].to_i) if chosen

      abs = File.join(source, rel_path)
      File.exist?(abs) ? File.mtime(abs) : nil
    end

    def ignored_sha?(sha, ignored)
      ignored.any? { |prefix| sha.start_with?(prefix) }
    end

    def marked?(subject, marker)
      marker && subject.to_s.include?(marker)
    end

    # [[sha, unix_committer_date, subject], ...] for commits touching
    # rel_path, newest first. Uses --follow so a file's history survives
    # being moved/renamed — without it, git log only sees commits at the
    # file's CURRENT path, so a move (even one tagged [structure]) looks like
    # the only commit there is, and the marker/ignore filtering below never
    # gets to the real history underneath. (Filtering by marker happens here
    # in Ruby rather than via `git log --invert-grep`, which silently returns
    # nothing when combined with --follow.) Empty on error / no git.
    def git_log_commits(source, rel_path)
      args = ['git', 'log', '--follow', '--format=%H%x01%ct%x01%s', '--', rel_path]

      out, status = Open3.capture2(*args, chdir: source)
      return [] unless status.success?

      out.each_line.filter_map do |line|
        sha, ct, subject = line.chomp.split("\x01", 3)
        [sha, ct.to_s.strip, subject] unless sha.to_s.empty? || ct.to_s.strip.empty?
      end
    rescue StandardError
      []
    end
  end
end
