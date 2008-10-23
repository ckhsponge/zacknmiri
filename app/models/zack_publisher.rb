class ZackPublisher < Facebooker::Rails::Publisher
  include ActorRole
  #File: lib/facebooker_publisher.rb Method: mini_feed
  def mini_feed(user)
#    send_as :action
#    self.from( user)
#    title "wants to star in a porno with Zack."
#    body "#{fb_name(user)} is a good actor."
#    image_1(image_path("fbtt.png"))
#    #image_1_link("http://chowder.msponge.com:8111") #outline_path(:only_path => false))
#    RAILS_DEFAULT_LOGGER.debug("Sending mini feed story for user #{user.id}")
    
    
      send_as :user_action
      self.from user
      data :friend=>"Mike"
  end
  
  def mini_feed_template
      one_line_story_template "{*actor*} did stuff with {*friend*}"
      one_line_story_template "{*actor*} did stuff"
      short_story_template "{*actor*} has a title {*friend*}", "short_body"
      short_story_template "{*actor*} has a title", "short_body"
      full_story_template "{*actor*} has a title {*friend*}", "full_body"
  end
  
  def feed_role(user,role)
    send_as :user_action
    self.from user
    data :role=>actor_role_text(role)
  end
  
  def feed_role_template
    one_line_story_template "{*actor*} wants to {*role*} - posted from #{link_to ENV['APP_NAME'],ENV['APP_URL']}"
  end
end
