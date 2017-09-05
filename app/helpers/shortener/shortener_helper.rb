module Shortener::ShortenerHelper

  # generate a url from a url string
  def short_url(url, **options)

    options[:fresh] ||= false
    options[:url_options] ||= {}
    
    short_url = Shortener::ShortenedUrl.generate(
      url,
      owner:      options[:owner],
      expires_at: options[:expires_at],
      fresh:      options[:fresh],
      category:   options[:category]
    )

    if short_url
      attrs = { controller: :"/shortener/shortened_urls", action: :show, id: short_url.unique_key, only_path: false }.merge(options[:url_options])
      url_for(attrs)
    else
      url
    end
  end

end
