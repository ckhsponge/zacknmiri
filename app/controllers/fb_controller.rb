class FbController < ApplicationController
  include ActorRole
  
  before_filter :load_data
  
  def index
    
  end
  
  def sign_out
    reset_session
    redirect_to "/"
  end
  
  def authenticate
    @facebook_session = Facebooker::Session.create(Facebooker.api_key, Facebooker.secret_key)
    session[:facebook_session] = @facebook_session
    redirect_to @facebook_session.login_url
  end
  
  def connect
    secure_with_token!
    redirect_to :action => "choose_role"
  end
  
  def choose_role
    @facebook_session = session[:facebook_session]
    @user = @facebook_session.user
  end
  
  def save_role
    begin
      @facebook_session = session[:facebook_session]
      user = @facebook_session.user
      ZackPublisher.register_feed_role(user)
      ZackPublisher.deliver_feed_role(user,params[:id])
      Role.create(:uid => user.id, :text => "#{user.name} wants to #{actor_role_text(params[:id])}")
      flash[:note] = "Your profile was successfully updated!"
      redirect_to :action => "action_success"
    rescue StandardError=>exc
      @user = nil
      flash[:error] = "Please sign in to facebook (#{exc.to_s})"
      redirect_to :action => "index"
    rescue Exception => exc2
      @user = nil
      flash[:error] = "Error: #{exc2.to_s}"
      redirect_to :action => "index"
    end
  end
  
  def send_email
    begin
      @facebook_session = session[:facebook_session]
      user = @facebook_session.user
      ZackPublisher.deliver_email(user)
      flash[:note] = "You have been sent an email!"
      redirect_to :action => "action_success"
    rescue StandardError=>exc
      flash[:error] = "Error: #{exc.to_s}"
      redirect_to :action => "index"
    end
  end
  
  def action_success
  end
  
  protected
  def load_data
    @roles = Role.find(:all, :limit => 100, :order => "created_at desc")
  end
  
end
