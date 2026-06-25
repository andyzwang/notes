# frozen_string_literal: true
module StripCaptionFilter
  def strip_caption(input)
    input.to_s.gsub(%r{<span[^>]*class=["'][^"']*main-image-caption[^"']*["'][^>]*>.*?</span>}im, '')
  end
end

Liquid::Template.register_filter(StripCaptionFilter)
