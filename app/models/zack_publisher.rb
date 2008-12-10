class ZackPublisher < Facebooker::Rails::Publisher
  include ActorRole
  
  def feed_role(user,role)
    send_as :user_action
    self.from user
    data :role=>actor_role_text(role)
  end
  
  def feed_role_template
    one_line_story_template "{*actor*} wants to {*role*} - posted from #{link_to ENV['APP_NAME'],ENV['APP_URL']}"
    short_story_template "{*actor*} wants to {*role*}","posted from #{link_to ENV['APP_NAME'],ENV['APP_URL']}"
  end
  
  def story_action_template
    one_line_story_template "{*actor*} wants to {*role*} - posted from #{link_to ENV['APP_NAME'],ENV['APP_URL']}"
    short_story_template "{*actor*} wants to {*role*}", "<i>{*comment*}</i><br/>posted from #{link_to ENV['APP_NAME'],ENV['APP_URL']}"
    full_story_template "{*actor*} wants to {*role*}", "<i>{*comment*}</i><br/>proudly posted from #{link_to ENV['APP_NAME'],ENV['APP_URL']}"
  end
  
#  def story_action
#    send_as :user_action
#    self.from user
#    data :role=>actor_role_text(role), :video => "http://www.youtube.com/v/wzyT9-9lUyE&hl=en&fs=1"
#  end
  
  def email(to,f = nil)
      send_as :email
      recipients to
      from f if f
      title "Zack N Miri think you are a star"
      fbml 'Congratulations! You are going to be a movie star with Zack N Miri.'
      text fbml
  end
  
  def self.register_if_needed(name)
    find_bundle_id(name)
  end
  
  def self.find_bundle_id(name)
    template = Facebooker::Rails::Publisher::FacebookTemplate.find_by_template_name(name)
    return template.bundle_id if template
    result = self.send("register_#{name}")
    return result
  end
end
