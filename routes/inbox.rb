require 'sinatra/base'

require 'a50c/peep'

class Inbox < Sinatra::Base

  configure do
    set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
    set :views, Proc.new { File.join(root, 'views/inbox') }
  end

  helpers do
    def protected!
      unless has_cookie?
        halt 401  # TODO: go to 50.io login page
      end
    end

    def has_cookie?
      request.cookies['api_key'] && request.cookies['api_pass']
    end

    def h(text)
      Rack::Utils.escape_html(text)
    end
  end

  before do
    protected! unless request.path_info == '/api_cookie'
    @p = A50C::Peep.new(request.cookies['api_key'], request.cookies['api_pass'])
  end

  post '/api_cookie' do
    if String(params[:api_key]).length == 8 && String(params[:api_pass]).length == 8
      # TODO: domain, SSL, expiration
      response.set_cookie('api_key', value: params[:api_key], path: '/')
      response.set_cookie('api_pass', value: params[:api_pass], path: '/')
      redirect '/'
    else
      redirect 'https://50.io/'  # TODO: dev domain?
    end
  end

  get '/' do
    @unopened_email_count = @p.unopened_email_count
    @open_emails = @p.open_emails
    @pagetitle = 'inbox'
    erb :home
  end

  get '/unopened' do
    @emails = @p.emails_unopened(params[:profile], params[:category])
    @pagetitle = 'unopened for %s: %s' % [params[:profile], params[:category]]
    erb :emails
  end

  post '/next_unopened' do
    email = @p.next_unopened_email(params[:profile], params[:category])
    if email
      redirect to('/email/%d' % email.id)
    else
      redirect to('/')
    end
  end

  get %r{\A/email/([0-9]+)\Z} do |id|
    @email = @p.open_email(id) || halt(404)
    @person = @p.get_person(@email.person.id)
    @pagetitle = 'email %d' % id
    erb :email
  end

  post %r{\A/email/([0-9]+)/unread\Z} do |id|
    @p.unread_email(id)
    redirect '/'
  end

  post %r{\A/email/([0-9]+)/close\Z} do |id|
    @p.close_email(id)
    email = @p.next_unopened_email(params[:profile], params[:category])
    if email
      redirect to('/email/%d' % email.id)
    else
      redirect to('/')
    end
  end

  post %r{\A/email/([0-9]+)/reply\Z} do |id|
    @p.reply_to_email(id, params[:reply])
    email = @p.next_unopened_email(params[:profile], params[:category])
    if email
      redirect to('/email/%d' % email.id)
    else
      redirect to('/')
    end
  end

  post %r{\A/email/([0-9]+)/not_my\Z} do |id|
    @p.not_my_email(id)
    redirect '/'
  end

end

