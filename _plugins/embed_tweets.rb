# frozen_string_literal: true

# Runs as a Jekyll Generator (during the `site.generate` phase).
# Disabled by default; set `embed_tweets: true` in _config.yml to turn
# bare tweet URLs into embedded tweet widgets.
class TweetEmbedGenerator < Jekyll::Generator
  def generate(site)
    return if !site.config["embed_tweets"]

    all_notes = site.collections['notes'].docs
    all_pages = site.pages
    all_docs = all_notes + all_pages

    all_docs.each do |current_note|
      # Match a bare tweet URL sitting alone on its own line (anchored ^...$):
      # optional #!/ fragment, the @handle, status or statuses, then the id.
      # Replace it with Twitter's standard embed markup. widgets.js turns the
      # <blockquote> into a rendered tweet; the "could not be embedded" text and
      # link are the fallback shown if that script fails to load. `\0` is the
      # whole matched URL, reused as the fallback link's href.
      current_note.content.gsub!(
        /^https?:\/\/twitter\.com\/(?:#!\/)?(\w+)\/status(es)?\/(\d+)$/i,
        <<~HTML
          <blockquote class="twitter-tweet">
           This tweet could not be embedded. <a href="#{'\0'}">View it on Twitter instead.</a>
          </blockquote>
          <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
        HTML
      )
    end
  end
end
