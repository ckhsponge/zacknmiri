class ZackController < ApplicationController
  include ActorRole
  
  before_filter :load_data
  before_filter :require_facebook_user, :only => [:choose_role, :save_role, :send_email, :action_success]
  
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
  end
  
  def save_role
    ZackPublisher.register_if_needed('feed_role')
    ZackPublisher.deliver_feed_role(@user,params[:id])
    Role.create(:uid => @user.id, :text => "#{@user.name} wants to #{actor_role_text(params[:id])}")
    flash[:note] = "Your profile was successfully updated!"
    redirect_to :action => "action_success"
  end
  
  def send_email
    ZackPublisher.deliver_email(@user)
    flash[:note] = "You have been sent an email!"
    redirect_to :action => "action_success"
  end
  
  def action_success
  end
  
  protected
  def load_data
    @roles = Role.find(:all, :limit => 100, :order => "created_at desc")
  end
  
end
