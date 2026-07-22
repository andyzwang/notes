# frozen_string_literal: true

# Runs on the `:site, :after_init` hook, before Jekyll reads any
# documents. Inject empty front matter into notes that don't have any,
# so they don't need to be created by hand for every new note.
EMPTY_FRONT_MATTER = <<~JEKYLL
  ---
  ---

JEKYLL

Jekyll::Hooks.register :site, :after_init do |site|
  Dir.glob(site.collections["notes"].relative_directory + "/**/*.md").each do |filename|
    # Only peek at the first few bytes rather than reading the whole
    # file, since most notes already have front matter and don't need
    # to be touched at all.
    next if File.open(filename, "r") { |f| f.read(3) } == "---"

    File.write(filename, EMPTY_FRONT_MATTER + File.read(filename))
  end
end
