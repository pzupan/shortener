require 'voight_kampff'

class Shortener::ShortenedUrlsController < ActionController::Base
  include Shortener

  def show
    token = ::Shortener::ShortenedUrl.extract_token(params[:id])
    track =  !Shortener.ignore_robots  || VoightKampff.human?(request.user_agent)
    url   = ::Shortener::ShortenedUrl.fetch_with_token(token: token, additional_params: params.to_unsafe_hash, track: track)
    redirect_to url[:url], status: :moved_permanently
  end

end
