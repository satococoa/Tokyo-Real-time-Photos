# coding: utf-8
require 'time'

configure do
  enable :sessions
end

configure :development do
  TITLE = 'Tokyo Real-time Photos - 東京の写真をリアルタイムに表示'
  config = YAML::load_file('config.yml')
  ADMIN = config['instagram']['admin']
  Instagram.configure do |conf|
    conf.client_id = config['instagram']['client_id']
    conf.client_secret = config['instagram']['client_secret']
  end
  REDIS = Redis.new
  Pusher.app_id = config['pusher']['app_id']
  Pusher.key    = config['pusher']['key']
  Pusher.secret = config['pusher']['secret']
end

configure :production do
  TITLE = 'Tokyo Real-time Photos - 東京の写真をリアルタイムに表示'
  ADMIN = ENV['INSTAGRAM_ADMIN']
  Instagram.configure do |conf|
    conf.client_id = ENV['INSTAGRAM_CLIENT_ID']
    conf.client_secret = ENV['INSTAGRAM_CLIENT_SECRET']
  end
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html
  def base_url
    "#{request.scheme}://#{request.host}#{':'+request.port.to_s if request.port != 80}/"
  end
  def callback_url
    base_url+'oauth/callback'
  end
  def subscript_url
    base_url+'subscription/callback'
  end
  def require_login
    unless login?
      redirect Instagram.authorize_url(:redirect_uri => callback_url)
    end
  end
  def login(res)
    session[:access_token] = res.access_token
    session[:user_id] = res.user.id
    session[:username] = res.user.username
    session[:icon] = res.user.profile_picture
  end
  def require_admin
    require_login
    redirect '/forbidden' unless session[:user_id].to_i == ADMIN.to_i
  end
  def logout
    session.delete :access_token
  end
  def login?
    !session[:access_token].nil?
  end
  def format_datetime(timestamp, format='%Y-%m-%d(%a) %H:%M:%S')
    Time.at(timestamp).strftime(format)
  end
end

get '/oauth/callback' do
  response = Instagram.get_access_token(params[:code], :redirect_uri => callback_url)
  login response
  redirect '/'
end

get '/logout' do
  logout
  'logged out'
end

get '/styles.css' do
  scss :styles
end

# 管理側
get '/admin' do
  require_admin
  client = Instagram.client(:access_token => session[:access_token])
  @subs = []
  client.subscriptions.each do |sub|
    data = REDIS.get("subscription:#{sub['object_id']}")
    @subs << JSON::parse(data) unless data.nil?
  end
  slim :admin, :locals => {:admin => true}
end

post '/admin/subscriptions' do
  require_admin
  client = Instagram.client(:access_token => session[:access_token])
  obj = client.create_subscription(:client_id => Instagram.options[:client_id],
                                   :client_secret => Instagram.options[:client_secret],
                                   :object => 'geography',
                                   :aspect => 'media',
                                   :lat => params[:lat],
                                   :lng => params[:lng],
                                   :radius => 5000,
                                   :callback_url => subscript_url)
  data = {:lat => params[:lat], :lng => params[:lng], :radius => 5000}
  REDIS.set("subscription:#{obj['object_id']}", data.to_json)
  obj
end

# delete all subscliptions
delete '/admin/subscriptions' do
  require_admin
  client = Instagram.client(:access_token => session[:access_token])
  client.delete_subscription :object => 'all'
  REDIS.flushdb
  200
end

get '/forbidden' do
  403
end

# subscription
get '/subscription/callback' do
  params[:'hub.challenge']
end

# Instagramからのリアルタイム通知を受け取る
post '/subscription/callback' do
  push_data = []
  Instagram.process_subscription(request.body.read, :signature => request['X-Hub-Signature']) do |handler|
    handler.on_geography_changed do |obj_id, obj|
      data = JSON::parse(REDIS.get("subscription:#{obj_id}"))
      max_timestamp = REDIS.get("subscription:#{obj_id}:max_timestamp")
      opt = {:distance => data['radius'], :count => 1, :min_timestamp => max_timestamp}
      images = Instagram.media_search(data['lat'], data['lng'], opt)
      images.each do |image|
        max_timestamp = REDIS.set("subscription:#{obj_id}:max_timestamp", image.created_time)
        photo_data = {:image_id => image.id,
                      :lat => image.location.latitude,
                      :lng => image.location.longitude,
                      :name => h(image.location.name),
                      :thumbnail => image.images.thumbnail.url,
                      :image => image.images.standard_resolution.url}
        REDIS.lpush('recent', photo_data.to_json)
        REDIS.ltrim 'recent', 0, 9
        push_data << photo_data
      end
    end
  end
  if ENV['PUSHER_STATUS'] == 'on'
    Pusher['tokyo-realtime-photos'].trigger('get_photo', push_data)
  end
  200
end

# ユーザー側
get '/' do
  @recent = REDIS.lrange('recent', 0, 9)
  slim :index, :locals => {:admin => false}
end
