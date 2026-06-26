# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'jekyll-last-modified-at'

module Recents
  # Runs as a Jekyll Generator (during the `site.generate` phase).
  # Shells out to `git log` once per note via the jekyll-last-modified-at
  # gem to populate "Last updated on" dates.
  class Generator < Jekyll::Generator
    def generate(site)
      items = site.collections['notes'].docs
      items.each do |page|
        timestamp = Jekyll::LastModifiedAt::Determinator.new(site.source, page.path, '%FT%T%:z').to_s
        page.data['last_modified_at_timestamp'] = timestamp
      end
    end
  end
end
