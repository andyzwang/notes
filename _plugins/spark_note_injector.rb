# frozen_string_literal: true

# Runs on the `:pre_render` hook, per note, right before kramdown converts the
# markdown to HTML. Appends a standard "spark note" notice to the end of any
# note whose `stage` front matter marks it as a spark (⚡️), so the notice lives
# in one place here instead of being copy-pasted into each spark note.
SPARK_NOTICE = "\n\n*⚡️ Spark note: This note is preliminary and will likely be expanded later.*\n"

Jekyll::Hooks.register [:notes], :pre_render do |doc|
  # `stage` holds the thoroughness emoji (⚡️ spark / ⭐️ star / 🌌 constellation).
  # Match the bolt itself (U+26A1) so it works with or without the trailing
  # emoji variation selector.
  next unless doc.data["stage"].to_s.include?("⚡")

  doc.content = doc.content.rstrip + SPARK_NOTICE
end
