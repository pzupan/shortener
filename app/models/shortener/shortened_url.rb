class Shortener::ShortenedUrl < ActiveRecord::Base

  REGEX_LINK_HAS_PROTOCOL = Regexp.new('\Ahttp:\/\/|\Ahttps:\/\/', Regexp::IGNORECASE)

  validates :url, presence: true

  # allows the shortened link to be associated with a user
  belongs_to :owner, polymorphic: true

  class << self

    def unexpired
      where('shortened_urls.expires_at IS NULL OR shortened_urls.expires_at > :time', time: ::Time.current.to_s(:db))
    end

  end

  # ensure the url starts with it protocol and is normalized
  def self.clean_url(url)

    url = url.to_s.strip
    if url !~ REGEX_LINK_HAS_PROTOCOL && url[0] != '/'
      url = "/#{url}"
    end
    URI.parse(url).normalize.to_s
  end

  # generate a shortened link from a url
  # link to a user if one specified
  # throw an exception if anything goes wrong
  def self.generate!(destination_url, owner: nil, expires_at: nil, fresh: false, category: nil)
    # if we get a shortened_url object with a different owner, generate
    # new one for the new owner. Otherwise return same object

    if destination_url.is_a? Shortener::ShortenedUrl
      result = if destination_url.owner == owner
        destination_url
      else
        generate!(
          destination_url.url,
          owner:      owner,
          expires_at: expires_at,
          fresh:      fresh,
          category:   category
        )
      end
    else 
      scope = owner ? owner.shortened_urls : self

      result = scope.where(url: clean_url(destination_url), category: category).first
      if result.blank? || fresh
        result = Shortener::ShortenedUrl.create(
          owner: owner,
          url: clean_url(destination_url),
          category: category,
          unique_key: generate_unique_key,
          expires_at: expires_at
          )
      end
    end
    result
  end

  # return shortened url on success, nil on failure
  def self.generate(destination_url, owner: nil, expires_at: nil, fresh: false, category: nil)
    begin
      generate!(
        destination_url,
        owner: owner,
        expires_at: expires_at,
        fresh: fresh,
        category: category
      )
    rescue => e
      logger.info e
      nil
    end
  end

  def self.extract_token(token_str)
    # only use the leading valid characters
    # escape to ensure custom charsets with protected chars do not fail
    /^([#{Regexp.escape(Shortener.key_chars.join)}]*).*/.match(token_str)[1]
  end

  def self.fetch_with_token(token: nil, additional_params: {}, track: true)
    shortened_url = if token.blank?
      nil
    else
     ::Shortener::ShortenedUrl.unexpired.find_by(unique_key: token)
    end

    url = if shortened_url.present?
      shortened_url.increment_usage_count if track
      merge_params_to_url(url: shortened_url.url, params: additional_params)
    else
      Shortener.default_redirect || '/'
    end

    { url: url, shortened_url: shortened_url }
  end

  def self.merge_params_to_url(url: nil, params: {})
    params.try(:except!, *[:id, :action, :controller])

    if params.present?
      uri = URI.parse(url)
      existing_params = Rack::Utils.parse_nested_query(uri.query)
      uri.query       = existing_params.symbolize_keys.merge(params).to_query
      url = uri.to_s
    end

    url
  end

  def increment_usage_count
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do |conn|
        increment!(:use_count)
      end
    end
  end

  def to_param
    unique_key
  end

  private

  def self.generate_unique_key
    charset = ::Shortener.key_chars
    custom_key = Shortener::ShortenedUrl.custom_key(charset)
    while Shortener::ShortenedUrl.find_by(unique_key: custom_key).present?
      custom_key = Shortener::ShortenedUrl.custom_key(charset)
    end
    custom_key
  end

  def self.custom_key(charset)
    (0...::Shortener.unique_key_length).map{ charset[rand(charset.size)] }.join
  end

end
