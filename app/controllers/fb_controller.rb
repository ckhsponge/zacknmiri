class FbController < ApplicationController
  include ActorRole
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
    @roles = Role.find(:all, :limit => 20, :order => "created_at desc")
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
        puts "*** profile #{@user.pic}"
        puts "*** profile #{@user.inspect}"
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
      Role.create(:uid => user.id, :text => "#{user.name} wants to #{actor_role_text(params[:id])}")
      flash[:note] = "Your Facebook profile has been updated"
      redirect_to :action => "index"
    rescue StandardError=>exc
      @user = nil
      flash[:note] = "Please sign in to facebook (#{exc.to_s})"
      redirect_to :action => "index"
    rescue Exception => exc2
      @user = nil
      flash[:note] = "Error: #{exc2.to_s}"
      redirect_to :action => "index"
    end
  end
  
  def invite
    flash[:note] = "Invitation sent"
    redirect_to "/"
  end
  
  def ignore
    flash[:note] = "Ignore"
    redirect_to "/"
  end
  
  def rsvp
    begin
      @facebook_session = session[:facebook_session]
      user = @facebook_session.user
      eid = "32102463702"
      events = @facebook_session.events(:eids => eid)
      puts "EVENTS #{events.inspect}"
      #attendance = Facebooker::Event::Attendance.new(:eid => eid, :uid => user.id)
      #puts "ATTENDANCE #{attendance.inspect}"
      #puts "EVENT #{attendance.event.inspect}"
      event = events[0]
      event.session = @facebook_session
      event.rsvp(user, "declined")
      flash[:note] = "RSVP"
      redirect_to "/"
    rescue StandardError=>exc
      flash[:note] = "Error: #{exc.to_s}"
      redirect_to :action => "index"
    end
  end
  
  def email
    begin
      @facebook_session = session[:facebook_session]
      user = @facebook_session.user
      ZackPublisher.deliver_email(user)
      flash[:note] = "Email sent"
      redirect_to :action => "index"
    rescue StandardError=>exc
      flash[:note] = "Error: #{exc.to_s}"
      redirect_to :action => "index"
    end
  end
end
