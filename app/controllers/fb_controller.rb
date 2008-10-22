class FbController < ApplicationController
  #ensure_authenticated_to_facebook #:except => [:index, :post_comment]
  #ensure_application_is_installed_by_facebook_user :except => :index
  
  def test
    #session.delete
#    user = Facebooker::User.new(:id => '1019141486')
#    puts user.inspect
#    puts user.status
#    puts facebook_params.inspect
#    @facebook_session = new_facebook_session
#    @facebook_session.secure_with!(facebook_params['session_key'], facebook_params['user'], facebook_params['expires'])
#    
    #set_facebook_session
    #@facebook_session = Facebooker::Session.create(Facebooker.api_key, Facebooker.secret_key)
    puts @facebook_session.inspect
#    @facebook_session.uid = '1019141486'
    puts @facebook_session.login_url
    
#    puts @facebook_session.user.inspect
    render :text=>'hi'
  end
  
  def test2
    set_facebook_session
    puts @facebook_session.inspect
    user = @facebook_session.user
    puts user.inspect
    puts user.friends.inspect
    
    render :text=>'test2'
  end
  
  def test3
    set_facebook_session
    puts @facebook_session.inspect
    user = @facebook_session.user
    user.status = "likes zack"
    
    render :text=>'test3'
  end
  
  def test4
    set_facebook_session
    puts @facebook_session.inspect
    user = @facebook_session.user
    
    ZackPublisher.register_mini_feed(user)
    #ZackPublisher.deliver_mini_feed(user)
    #flash[:notice] = "Check your Mini-Feed in a little while. You should see a news item from Facebooker."
    
    render :text=>'test4'
  end
  
  def test5
    set_facebook_session
    puts @facebook_session.inspect
    user = @facebook_session.user
    
    #ZackPublisher.register_mini_feed(user)
    ZackPublisher.deliver_mini_feed(user)
    flash[:notice] = "Check your Mini-Feed in a little while. You should see a news item from Facebooker."
    
    render :text=>'test4'
  end
  
  def index
    secure_with_token!
    #set_facebook_session
    puts "fb #{@facebook_session.inspect}"
    puts "cookies #{cookies.inspect}"
    puts "session #{session.inspect}"
    @facebook_session = session[:facebook_session]
    @user = nil
    if @facebook_session
      begin
        @user = @facebook_session.user
        puts "*** profile #{@user.name}"
      rescue StandardError=>exc
        puts "StandardError: #{exc.to_s}"
        @user = nil
      end
    end
    #session[:t] = 'bye'
  end
  
  def authenticate
    #reset_session
    #set_facebook_session
    @facebook_session = Facebooker::Session.create(Facebooker.api_key, Facebooker.secret_key)
    session[:facebook_session] = @facebook_session
    redirect_to @facebook_session.login_url
    #create_new_facebook_session_and_redirect!
  end
  
  def post_comment
    puts "post session #{session.inspect}"
    begin
      #set_facebook_session
      @facebook_session = session[:facebook_session]
      user = @facebook_session.user
      ZackPublisher.register_feed_role(user)
      ZackPublisher.deliver_feed_role(user,params[:id])
      redirect_to :action => "index"
    rescue StandardError=>exc
      puts "StandardError: #{exc.to_s}"
      @user = nil
      flash[:note] = "Please sign in to facebook"
      redirect_to :action => "index"
    end
  end
end
