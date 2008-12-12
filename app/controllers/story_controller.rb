#How many different ways can we post stories to walls?
class StoryController < ApplicationController
  include ActorRole
  
  before_filter :require_facebook_user, :except => [:feed_action, :not_signed_in]
  
  def not_signed_in
    
  end
  
  def one_line_api
    begin
      ZackPublisher.register_if_needed('feed_role')
      ZackPublisher.deliver_feed_role(@user,params[:id])
      Role.create(:uid => @user.id, :text => "#{@user.name} wants to #{actor_role_text(params[:id])}")
      flash[:note] = "Your profile was successfully updated!"
    rescue Facebooker::Session::TooManyUserActionCalls => tmuac
      flash[:note] = "Too many user action calls: #{tmuac}"
    end
    render :action => "complete"
  end
  
  
  def feed_form
    @facebook_session = session[:facebook_session]
    @user = @facebook_session.user
    #result = ZackPublisher.register_story_action(@user)
    #puts "reg result #{result.id}"
  end
  
  def feed_form2
    render :action => "feed_form2" , :layout => false
  end
  
  def feed_action
    url = url_for :action => "success_text", :only_path => false
    
    data = {:template_id => ZackPublisher.find_bundle_id('story_action'), 
      :template_data => {:role => "use the force", :comment => params[:comment], 
        :video => {:video_src =>"http://www.youtube.com/v/OssgMY_mkMc&hl=en&fs=1", :preview_img => "http://zacknmiri.com/images/f1.znm.png"}
      }
    }
    
    feedStory = { :method  => 'feedStory',
                  :content => { :feed => data,
                                :next => url }}
    render :text => feedStory.to_json
  end
  
  def complete
    
  end
  
  def success_text
    render :text => "Success!"
  end
  
end
