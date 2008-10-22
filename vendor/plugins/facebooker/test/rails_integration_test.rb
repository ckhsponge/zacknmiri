require File.dirname(__FILE__) + '/test_helper.rb'
begin
  require 'action_controller'
  require 'action_controller/test_process'
  require 'facebooker/rails/controller'
  require 'facebooker/rails/helpers'
  require 'facebooker/rails/facebook_form_builder'
  require File.dirname(__FILE__)+'/../init'
  require 'mocha'
  
  ActionController::Routing::Routes.draw do |map|
    map.connect '', :controller=>"facebook",:conditions=>{:canvas=>true}
    map.connect '', :controller=>"plain_old_rails"
    map.resources :comments, :controller=>"plain_old_rails"
    map.connect 'require_auth/:action', :controller => "controller_which_requires_facebook_authentication"
    map.connect 'require_install/:action', :controller => "controller_which_requires_application_installation"
    map.connect ':controller/:action/:id', :controller => "plain_old_rails"
  end  
  
  class NoisyController < ActionController::Base
    include Facebooker::Rails::Controller
    def rescue_action(e) raise e end
  end
  class ControllerWhichRequiresExtendedPermissions< NoisyController
    ensure_authenticated_to_facebook
    before_filter :ensure_has_status_update
    before_filter :ensure_has_photo_upload
    before_filter :ensure_has_create_listing
    def index
      render :text => 'score!'
    end
  end
  
  class ControllerWhichRequiresFacebookAuthentication < NoisyController
    ensure_authenticated_to_facebook
    def index
      render :text => 'score!'
    end
    def link_test
      options = {}
      options[:canvas] = true if params[:canvas] == true
      options[:canvas] = false if params[:canvas] == false
      render :text=>url_for(options)
    end
    
     def named_route_test
      render :text=>comments_url()
    end
    
    def image_test
      render :inline=>"<%=image_tag 'image.png'%>"
    end
    
    def fb_params_test
      render :text=>facebook_params['user']
    end
    
    def publisher_test
      if wants_interface?
        render :text=>"interface"
      else
        render :text=>"not interface"
      end
    end
    
    def publisher_test_interface
      render_publisher_interface("This is a test",false,true)
    end
    
    def publisher_test_response
      ua=Facebooker::Rails::Publisher::UserAction.new
      ua.data = {:params=>true}
      ua.template_name = "template_name"
      ua.template_id =  1234
      render_publisher_response(ua)
    end
    
    def publisher_test_error
      render_publisher_error("Title","Body")
    end
    
  end
  class ControllerWhichRequiresApplicationInstallation < NoisyController
    ensure_application_is_installed_by_facebook_user
    def index
      render :text => 'installed!'
    end    
  end
  class FacebookController < ActionController::Base
    def index
    end
  end
  
  class PlainOldRailsController < ActionController::Base
    def index
    end
    def link_test
      options = {}
      options[:canvas] = true if params[:canvas] == true
      options[:canvas] = false if params[:canvas] == false
      render :text => url_for(options)
    end
    
    def named_route_test
      render :text=>comments_url()
    end
    def canvas_false_test
      render :text=>comments_url(:canvas=>false)
    end
    def canvas_true_test
      render :text=>comments_url(:canvas=>true)
    end
  end
  
  class ControllerWhichFails < ActionController::Base
    def pass
      render :text=>''
    end
    def fail
      raise "I'm failing"
    end
  end
  
  # you can't use asset_recognize, because it can't pass parameters in to the requests
  class UrlRecognitionTests < Test::Unit::TestCase
    def test_detects_in_canvas
      request = ActionController::TestRequest.new({"fb_sig_in_canvas"=>"1"}, {}, nil)
      request.path   = "/"
      ActionController::Routing::Routes.recognize(request)
      assert_equal({"controller"=>"facebook","action"=>"index"},request.path_parameters)
    end
    
    def test_routes_when_not_in_canvas
      request = ActionController::TestRequest.new({}, {}, nil)
      request.path   = "/"
      ActionController::Routing::Routes.recognize(request)
      assert_equal({"controller"=>"plain_old_rails","action"=>"index"},request.path_parameters)
    end
  end
  
  class RailsIntegrationTestForNonFacebookControllers < Test::Unit::TestCase
    def setup
      ENV['FACEBOOK_CANVAS_PATH'] ='facebook_app_name'
      ENV['FACEBOOK_API_KEY'] = '1234567'
      ENV['FACEBOOK_SECRET_KEY'] = '7654321'
      @controller = PlainOldRailsController.new
      @request    = ActionController::TestRequest.new
      @response   = ActionController::TestResponse.new        
    end

    def test_url_for_links_to_callback_if_canvas_is_false_and_in_canvas
      get :link_test, example_rails_params
      assert_match /test.host/,@response.body
    end
    
    def test_named_route_doesnt_include_canvas_path_when_not_in_canvas
      get :named_route_test, example_rails_params
      assert_equal "http://test.host/comments",@response.body
    end
    def test_named_route_includes_canvas_path_when_in_canvas
      get :named_route_test, example_rails_params_including_fb
      assert_equal "http://apps.facebook.com/facebook_app_name/comments",@response.body
    end
   
    def test_named_route_doesnt_include_canvas_path_when_in_canvas_with_canvas_equals_false
      get :canvas_false_test, example_rails_params_including_fb
      assert_equal "http://test.host/comments",@response.body
    end
    def test_named_route_does_include_canvas_path_when_not_in_canvas_with_canvas_equals_true
      get :canvas_true_test, example_rails_params
      assert_equal "http://apps.facebook.com/facebook_app_name/comments",@response.body
    end
    
    private
    def example_rails_params
      { "action"=>"index", "controller"=>"plain_old_rails_controller" }    
    end
    def example_rails_params_including_fb(options={})
      {"fb_sig_time"=>"1186588275.5988", "fb_sig"=>"8d9e9dd2cb0742a5a2bfe35563134585", "action"=>"index", "fb_sig_in_canvas"=>"1", "fb_sig_session_key"=>"c452b5d5d60cbd0a0da82021-744961110", "controller"=>"controller_which_requires_facebook_authentication", "fb_sig_expires"=>"0", "fb_sig_friends"=>"417358,702720,1001170,1530839,3300204,3501584,6217936,9627766,9700907,22701786,33902768,38914148,67400422,135301144,157200364,500103523,500104930,500870819,502149612,502664898,502694695,502852293,502985816,503254091,504510130,504611551,505421674,509229747,511075237,512548373,512830487,517893818,517961878,518890403,523589362,523826914,525812984,531555098,535310228,539339781,541137089,549405288,552706617,564393355,564481279,567640762,568091401,570201702,571469972,573863097,574415114,575543081,578129427,578520568,582262836,582561201,586550659,591631962,592318318,596269347,596663221,597405464,599764847,602995438,606661367,609761260,610544224,620049417,626087078,628803637,632686250,641422291,646763898,649678032,649925863,653288975,654395451,659079771,661794253,665861872,668960554,672481514,675399151,678427115,685772348,686821151,687686894,688506532,689275123,695551670,710631572,710766439,712406081,715741469,718976395,719246649,722747311,725327717,725683968,725831016,727580320,734151780,734595181,737944528,748881410,752244947,763868412,768578853,776596978,789728437,873695441", "fb_sig_added"=>"0", "fb_sig_api_key"=>"b6c9c857ac543ca806f4d3187cd05e09", "fb_sig_user"=>"744961110", "fb_sig_profile_update_time"=>"1180712453"}.merge(options)
    end
  
  end
  
class RailsIntegrationTestForExtendedPermissions < Test::Unit::TestCase
  def setup
    ENV['FACEBOOK_API_KEY'] = '1234567'
    ENV['FACEBOOK_SECRET_KEY'] = '7654321'
    @controller = ControllerWhichRequiresExtendedPermissions.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller.stubs(:verify_signature).returns(true)
  end
  
  def test_redirects_without_set_status
    post :index,example_rails_params_including_fb
    assert_response :success
    assert_equal("<fb:redirect url=\"http://www.facebook.com/authorize.php?api_key=1234567&v=1.0&ext_perm=status_update\" />", @response.body)
  end
  def test_redirects_without_photo_upload
    post :index,example_rails_params_including_fb.merge(:fb_sig_ext_perms=>"status_update")
    assert_response :success
    assert_equal("<fb:redirect url=\"http://www.facebook.com/authorize.php?api_key=1234567&v=1.0&ext_perm=photo_upload\" />", @response.body)
  end
  def test_redirects_without_create_listing
    post :index,example_rails_params_including_fb.merge(:fb_sig_ext_perms=>"status_update,photo_upload")
    assert_response :success
    assert_equal("<fb:redirect url=\"http://www.facebook.com/authorize.php?api_key=1234567&v=1.0&ext_perm=create_listing\" />", @response.body)
  end
  
  def test_renders_with_permission
    post :index,example_rails_params_including_fb.merge(:fb_sig_ext_perms=>"status_update,photo_upload,create_listing")
    assert_response :success
    assert_equal("score!", @response.body)
    
  end
  private
    def example_rails_params_including_fb
      {"fb_sig_time"=>"1186588275.5988", "fb_sig"=>"7371a6400329b229f800a5ecafe03b0a", "action"=>"index", "fb_sig_in_canvas"=>"1", "fb_sig_session_key"=>"c452b5d5d60cbd0a0da82021-744961110", "controller"=>"controller_which_requires_facebook_authentication", "fb_sig_expires"=>"0", "fb_sig_friends"=>"417358,702720,1001170,1530839,3300204,3501584,6217936,9627766,9700907,22701786,33902768,38914148,67400422,135301144,157200364,500103523,500104930,500870819,502149612,502664898,502694695,502852293,502985816,503254091,504510130,504611551,505421674,509229747,511075237,512548373,512830487,517893818,517961878,518890403,523589362,523826914,525812984,531555098,535310228,539339781,541137089,549405288,552706617,564393355,564481279,567640762,568091401,570201702,571469972,573863097,574415114,575543081,578129427,578520568,582262836,582561201,586550659,591631962,592318318,596269347,596663221,597405464,599764847,602995438,606661367,609761260,610544224,620049417,626087078,628803637,632686250,641422291,646763898,649678032,649925863,653288975,654395451,659079771,661794253,665861872,668960554,672481514,675399151,678427115,685772348,686821151,687686894,688506532,689275123,695551670,710631572,710766439,712406081,715741469,718976395,719246649,722747311,725327717,725683968,725831016,727580320,734151780,734595181,737944528,748881410,752244947,763868412,768578853,776596978,789728437,873695441", "fb_sig_added"=>"0", "fb_sig_api_key"=>"b6c9c857ac543ca806f4d3187cd05e09", "fb_sig_user"=>"744961110", "fb_sig_profile_update_time"=>"1180712453"}
    end
  
end  
  
class RailsIntegrationTestForApplicationInstallation < Test::Unit::TestCase
  def setup
    ENV['FACEBOOK_API_KEY'] = '1234567'
    ENV['FACEBOOK_SECRET_KEY'] = '7654321'
    @controller = ControllerWhichRequiresApplicationInstallation.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller.stubs(:verify_signature).returns(true)
  end
  
  def test_if_controller_requires_application_installation_unauthenticated_requests_will_redirect_to_install_page
    get :index
    assert_response :redirect
    assert_equal("http://www.facebook.com/install.php?api_key=1234567&v=1.0", @response.headers['Location'])
  end
  
  def test_if_controller_requires_application_installation_authenticated_requests_without_installation_will_redirect_to_install_page
    get :index, example_rails_params_including_fb
    assert_response :success
    assert_equal("<fb:redirect url=\"http://www.facebook.com/install.php?api_key=1234567&v=1.0\" />", @response.body)
  end
  
  def test_if_controller_requires_application_installation_authenticated_requests_with_installation_will_render
    get :index, example_rails_params_including_fb.merge('fb_sig_added' => "1")
    assert_response :success
    assert_equal("installed!", @response.body)
  end
  
  private
    def example_rails_params_including_fb
      {"fb_sig_time"=>"1186588275.5988", "fb_sig"=>"7371a6400329b229f800a5ecafe03b0a", "action"=>"index", "fb_sig_in_canvas"=>"1", "fb_sig_session_key"=>"c452b5d5d60cbd0a0da82021-744961110", "controller"=>"controller_which_requires_facebook_authentication", "fb_sig_expires"=>"0", "fb_sig_friends"=>"417358,702720,1001170,1530839,3300204,3501584,6217936,9627766,9700907,22701786,33902768,38914148,67400422,135301144,157200364,500103523,500104930,500870819,502149612,502664898,502694695,502852293,502985816,503254091,504510130,504611551,505421674,509229747,511075237,512548373,512830487,517893818,517961878,518890403,523589362,523826914,525812984,531555098,535310228,539339781,541137089,549405288,552706617,564393355,564481279,567640762,568091401,570201702,571469972,573863097,574415114,575543081,578129427,578520568,582262836,582561201,586550659,591631962,592318318,596269347,596663221,597405464,599764847,602995438,606661367,609761260,610544224,620049417,626087078,628803637,632686250,641422291,646763898,649678032,649925863,653288975,654395451,659079771,661794253,665861872,668960554,672481514,675399151,678427115,685772348,686821151,687686894,688506532,689275123,695551670,710631572,710766439,712406081,715741469,718976395,719246649,722747311,725327717,725683968,725831016,727580320,734151780,734595181,737944528,748881410,752244947,763868412,768578853,776596978,789728437,873695441", "fb_sig_added"=>"0", "fb_sig_api_key"=>"b6c9c857ac543ca806f4d3187cd05e09", "fb_sig_user"=>"744961110", "fb_sig_profile_update_time"=>"1180712453"}
    end
end
  
class RailsIntegrationTest < Test::Unit::TestCase
  def setup
    ENV['FACEBOOK_CANVAS_PATH'] ='root'
    ENV['FACEBOOK_API_KEY'] = '1234567'
    ENV['FACEBOOK_SECRET_KEY'] = '7654321'
    ActionController::Base.asset_host="http://root.example.com"
    @controller = ControllerWhichRequiresFacebookAuthentication.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new    
    @controller.stubs(:verify_signature).returns(true)
    
  end
  
   def test_named_route_includes_new_canvas_path_when_in_new_canvas
      get :named_route_test, example_rails_params_including_fb.merge("fb_sig_in_new_facebook"=>"1")
      assert_equal "http://apps.facebook.com/root/comments",@response.body
    end

  def test_if_controller_requires_facebook_authentication_unauthenticated_requests_will_redirect
    get :index
    assert_response :redirect
    assert_equal("http://www.facebook.com/login.php?api_key=1234567&v=1.0", @response.headers['Location'])
  end

  def test_facebook_params_are_parsed_into_a_separate_hash
    get :index, example_rails_params_including_fb
    facebook_params = @controller.facebook_params
    assert_equal([8, 8], [facebook_params['time'].day, facebook_params['time'].mon])
  end
  
  def test_facebook_params_convert_in_canvas_to_boolean
    get :index, example_rails_params_including_fb
    assert_equal(true, @controller.facebook_params['in_canvas'])    
  end
  
  def test_facebook_params_convert_added_to_boolean_false
    get :index, example_rails_params_including_fb
    assert_equal(false, @controller.facebook_params['added'])
  end
  
  def test_facebook_params_convert_added_to_boolean_true
    get :index, example_rails_params_including_fb.merge('fb_sig_added' => "1")
    assert_equal(true, @controller.facebook_params['added'])
  end
  
  def test_facebook_params_convert_expirey_into_time_or_nil
    get :index, example_rails_params_including_fb
    assert_nil(@controller.facebook_params['expires'])
    modified_params = example_rails_params_including_fb
    modified_params['fb_sig_expires'] = modified_params['fb_sig_time']
    setup # reset session and cached params
    get :index, modified_params
    assert_equal([8, 8], [@controller.facebook_params['time'].day, @controller.facebook_params['time'].mon])    
  end
  
  def test_facebook_params_convert_friend_list_to_parsed_array_of_friend_ids
    get :index, example_rails_params_including_fb
    assert_kind_of(Array, @controller.facebook_params['friends'])    
    assert_equal(111, @controller.facebook_params['friends'].size)
  end
  
  def test_session_can_be_resecured_from_facebook_params
    get :index, example_rails_params_including_fb
    assert_equal(744961110, @controller.facebook_session.user.id)    
  end
  
  def test_existing_secured_session_is_used_if_available
    session = Facebooker::Session.create(ENV['FACEBOOK_API_KEY'], ENV['FACEBOOK_SECRET_KEY'])
    session.secure_with!("c452b5d5d60cbd0a0da82021-744961110", "1111111", Time.now.to_i + 60)
    get :index, example_rails_params_including_fb, {:facebook_session => session}
    assert_equal(1111111, @controller.facebook_session.user.id)
  end

  def test_facebook_params_used_if_existing_secured_session_key_does_not_match
    session = Facebooker::Session.create(ENV['FACEBOOK_API_KEY'], ENV['FACEBOOK_SECRET_KEY'])
    session.secure_with!("a session key", "1111111", Time.now.to_i + 60)
    get :index, example_rails_params_including_fb, {:facebook_session => session}
    assert_equal(744961110, @controller.facebook_session.user.id)
  end

  def test_existing_secured_session_is_NOT_used_if_available_and_facebook_params_session_key_is_nil_and_in_canvas
    session = Facebooker::Session.create(ENV['FACEBOOK_API_KEY'], ENV['FACEBOOK_SECRET_KEY'])
    session.secure_with!("a session key", "1111111", Time.now.to_i + 60)
    get :index, example_rails_params_including_fb.merge("fb_sig_session_key" => ''), {:facebook_session => session}
    
    assert_equal(744961110, @controller.facebook_session.user.id)
  end

  def test_existing_secured_session_IS_used_if_available_and_facebook_params_session_key_is_nil_and_NOT_in_canvas
    @contoller = PlainOldRailsController.new
    session = Facebooker::Session.create(ENV['FACEBOOK_API_KEY'], ENV['FACEBOOK_SECRET_KEY'])
    session.secure_with!("a session key", "1111111", Time.now.to_i + 60)
    get :index,{}, {:facebook_session => session}
    
    assert_equal(1111111, @controller.facebook_session.user.id)
  end

  def test_session_can_be_secured_with_auth_token
    auth_token = 'ohaiauthtokenhere111'
    modified_params = example_rails_params_including_fb
    modified_params.delete('fb_sig_session_key')
    modified_params['auth_token'] = auth_token
    session_mock = flexmock(session = Facebooker::Session.create(ENV['FACEBOOK_API_KEY'], ENV['FACEBOOK_SECRET_KEY']))
    session_params = { 'session_key' => '123', 'uid' => '321' }
    session_mock.should_receive(:post).with('facebook.auth.getSession', :auth_token => auth_token).once.and_return(session_params).ordered
    flexmock(@controller).should_receive(:new_facebook_session).once.and_return(session).ordered
    get :index, modified_params
  end
  
  def test_user_friends_can_be_populated_from_facebook_params_if_available
    get :index, example_rails_params_including_fb
    assert_not_nil(friends = @controller.facebook_session.user.friends)
    assert_equal(111, friends.size)    
  end
  
  def test_fbml_redirect_tag_handles_hash_parameters_correctly
    get :index, example_rails_params_including_fb
    assert_equal "<fb:redirect url=\"http://apps.facebook.com/root/require_auth\" />", @controller.send(:fbml_redirect_tag, :action => :index,:canvas=>true)
  end
  
  def test_redirect_to_renders_fbml_redirect_tag_if_request_is_for_a_facebook_canvas
    get :index, example_rails_params_including_fb_for_user_not_logged_into_application
    assert_response :success
    assert_equal("<fb:redirect url=\"http://www.facebook.com/login.php?api_key=1234567&v=1.0\" />", @response.body)
  end
  
  def test_url_for_links_to_canvas_if_canvas_is_true_and_not_in_canvas
    get :link_test,example_rails_params_including_fb.merge(:fb_sig_in_canvas=>0,:canvas=>true)
    assert_match /apps.facebook.com/,@response.body
  end
  
  def test_includes_relative_url_root_when_linked_to_canvas
    get :link_test,example_rails_params_including_fb.merge(:fb_sig_in_canvas=>0,:canvas=>true)
    assert_match /root/,@response.body
  end

  def test_url_for_links_to_callback_if_canvas_is_false_and_in_canvas
    get :link_test,example_rails_params_including_fb.merge(:fb_sig_in_canvas=>0,:canvas=>false)
    assert_match /test.host/,@response.body
  end

  def test_url_for_doesnt_include_url_root_when_not_linked_to_canvas
    get :link_test,example_rails_params_including_fb.merge(:fb_sig_in_canvas=>0,:canvas=>false)
    assert !@response.body.match(/root/)
  end
  
  def test_url_for_links_to_canvas_if_canvas_is_not_set
    get :link_test,example_rails_params_including_fb
    assert_match /apps.facebook.com/,@response.body
  end
  
  def test_image_tag
    get :image_test, example_rails_params_including_fb
    assert_equal "<img alt=\"Image\" src=\"http://root.example.com/images/image.png\" />",@response.body
  end
  
  def test_wants_interface_is_available_and_detects_method
    get :publisher_test, example_rails_params_including_fb.merge(:method=>"publisher_getInterface")
    assert_equal "interface",@response.body
  end
  def test_wants_interface_is_available_and_detects_not_interface
    get :publisher_test, example_rails_params_including_fb.merge(:method=>"publisher_getFeedStory")
    assert_equal "not interface",@response.body
  end
  
  def test_publisher_test_error
    get :publisher_test_error, example_rails_params_including_fb
    assert_equal JSON.parse("{\"errorCode\": 1, \"errorTitle\": \"Title\", \"errorMessage\": \"Body\"}"), JSON.parse(@response.body)
  end
  
  def test_publisher_test_interface
    get :publisher_test_interface, example_rails_params_including_fb
    assert_equal JSON.parse("{\"method\": \"publisher_getInterface\", \"content\": {\"fbml\": \"This is a test\", \"publishEnabled\": false, \"commentEnabled\": true}}"), JSON.parse(@response.body)
  end
  
  def test_publisher_test_reponse
    get :publisher_test_response, example_rails_params_including_fb
    assert_equal JSON.parse("{\"method\": \"publisher_getFeedStory\", \"content\": {\"feed\": {\"template_data\": {\"params\": true}, \"template_id\": 1234}}}"), JSON.parse(@response.body)
    
  end
  
  private
  def example_rails_params_including_fb_for_user_not_logged_into_application
    {"fb_sig_time"=>"1186588275.5988", "fb_sig"=>"7371a6400329b229f800a5ecafe03b0a", "action"=>"index", "fb_sig_in_canvas"=>"1", "controller"=>"controller_which_requires_facebook_authentication", "fb_sig_added"=>"0", "fb_sig_api_key"=>"b6c9c857ac543ca806f4d3187cd05e09"}
  end
  
  def example_rails_params_including_fb
    {"fb_sig_time"=>"1186588275.5988", "fb_sig"=>"7371a6400329b229f800a5ecafe03b0a", "action"=>"index", "fb_sig_in_canvas"=>"1", "fb_sig_session_key"=>"c452b5d5d60cbd0a0da82021-744961110", "controller"=>"controller_which_requires_facebook_authentication", "fb_sig_expires"=>"0", "fb_sig_friends"=>"417358,702720,1001170,1530839,3300204,3501584,6217936,9627766,9700907,22701786,33902768,38914148,67400422,135301144,157200364,500103523,500104930,500870819,502149612,502664898,502694695,502852293,502985816,503254091,504510130,504611551,505421674,509229747,511075237,512548373,512830487,517893818,517961878,518890403,523589362,523826914,525812984,531555098,535310228,539339781,541137089,549405288,552706617,564393355,564481279,567640762,568091401,570201702,571469972,573863097,574415114,575543081,578129427,578520568,582262836,582561201,586550659,591631962,592318318,596269347,596663221,597405464,599764847,602995438,606661367,609761260,610544224,620049417,626087078,628803637,632686250,641422291,646763898,649678032,649925863,653288975,654395451,659079771,661794253,665861872,668960554,672481514,675399151,678427115,685772348,686821151,687686894,688506532,689275123,695551670,710631572,710766439,712406081,715741469,718976395,719246649,722747311,725327717,725683968,725831016,727580320,734151780,734595181,737944528,748881410,752244947,763868412,768578853,776596978,789728437,873695441", "fb_sig_added"=>"0", "fb_sig_api_key"=>"b6c9c857ac543ca806f4d3187cd05e09", "fb_sig_user"=>"744961110", "fb_sig_profile_update_time"=>"1180712453"}
  end
end


class RailsSignatureTest < Test::Unit::TestCase
  def setup
    ENV['FACEBOOKER_RELATIVE_URL_ROOT'] ='root'
    ENV['FACEBOOK_API_KEY'] = '1234567'
    ENV['FACEBOOK_SECRET_KEY'] = '7654321'
    @controller = ControllerWhichRequiresFacebookAuthentication.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new    

  end
  
  def test_should_raise_too_old_for_replayed_session
    begin
      get :fb_params_test,example_rails_params_including_fb
      fail "No SignatureTooOld raised"
    rescue Facebooker::Session::SignatureTooOld=>e
    end
  end
  
  def test_should_raise_on_bad_sig
    begin
      get :fb_params_test,example_rails_params_including_fb("fb_sig"=>'incorrect')
      fail "No IncorrectSignature raised"
    rescue Facebooker::Session::IncorrectSignature=>e
    end
  end
  
  def test_valid_signature
    @controller.expects(:earliest_valid_session).returns(Time.at(1186588275.5988)-1)
    get :fb_params_test,example_rails_params_including_fb
    
  end
  
  def example_rails_params_including_fb(options={})
    {"fb_sig_time"=>"1186588275.5988", "fb_sig"=>"8d9e9dd2cb0742a5a2bfe35563134585", "action"=>"index", "fb_sig_in_canvas"=>"1", "fb_sig_session_key"=>"c452b5d5d60cbd0a0da82021-744961110", "controller"=>"controller_which_requires_facebook_authentication", "fb_sig_expires"=>"0", "fb_sig_friends"=>"417358,702720,1001170,1530839,3300204,3501584,6217936,9627766,9700907,22701786,33902768,38914148,67400422,135301144,157200364,500103523,500104930,500870819,502149612,502664898,502694695,502852293,502985816,503254091,504510130,504611551,505421674,509229747,511075237,512548373,512830487,517893818,517961878,518890403,523589362,523826914,525812984,531555098,535310228,539339781,541137089,549405288,552706617,564393355,564481279,567640762,568091401,570201702,571469972,573863097,574415114,575543081,578129427,578520568,582262836,582561201,586550659,591631962,592318318,596269347,596663221,597405464,599764847,602995438,606661367,609761260,610544224,620049417,626087078,628803637,632686250,641422291,646763898,649678032,649925863,653288975,654395451,659079771,661794253,665861872,668960554,672481514,675399151,678427115,685772348,686821151,687686894,688506532,689275123,695551670,710631572,710766439,712406081,715741469,718976395,719246649,722747311,725327717,725683968,725831016,727580320,734151780,734595181,737944528,748881410,752244947,763868412,768578853,776596978,789728437,873695441", "fb_sig_added"=>"0", "fb_sig_api_key"=>"b6c9c857ac543ca806f4d3187cd05e09", "fb_sig_user"=>"744961110", "fb_sig_profile_update_time"=>"1180712453"}.merge(options)
  end

end
class RailsHelperTest < Test::Unit::TestCase
  class HelperClass
    include ActionView::Helpers::TextHelper
    include ActionView::Helpers::CaptureHelper
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::AssetTagHelper
    include Facebooker::Rails::Helpers
    attr_accessor :flash
    def initialize
      @flash={}
      @template = self
      @content_for_test_param="Test Param"
    end
    #used for stubbing out the form builder
    def url_for(arg)
      arg
    end
    def fields_for(*args)
      ""
    end
    
  end 

  # used for capturing the contents of some of the helper tests
  # this duplicates the rails template system  
  attr_accessor :_erbout
  
  def setup
    ENV['FACEBOOK_CANVAS_PATH'] ='facebook'
    ENV['FACEBOOK_API_KEY'] = '1234567'
    ENV['FACEBOOK_SECRET_KEY'] = '7654321'
    
    @_erbout = ""
    @h = HelperClass.new
    #use an asset path where the canvas path equals the hostname to make sure we handle that case right
    ActionController::Base.asset_host='http://facebook.host.com'
  end
  
  def test_fb_profile_pic
    assert_equal "<fb:profile-pic uid=\"1234\" />", @h.fb_profile_pic("1234")
  end

  def test_fb_profile_pic_with_valid_size
    assert_equal "<fb:profile-pic size=\"small\" uid=\"1234\" />", @h.fb_profile_pic("1234", :size => :small)
  end

  def test_fb_profile_pic_with_invalid_size
    assert_raises(ArgumentError) {@h.fb_profile_pic("1234", :size => :mediumm)}
  end

  def test_fb_photo
    assert_equal "<fb:photo pid=\"1234\" />",@h.fb_photo("1234")
  end

  def test_fb_photo_with_object_responding_to_photo_id
    photo = flexmock("photo", :photo_id => "5678")
    assert_equal "<fb:photo pid=\"5678\" />", @h.fb_photo(photo)
  end

  def test_fb_photo_with_invalid_size
    assert_raises(ArgumentError) {@h.fb_photo("1234", :size => :medium)}
  end
  
  def test_fb_photo_with_invalid_size_value
    assert_raises(ArgumentError) {@h.fb_photo("1234", :size => :mediumm)}
  end
  
  def test_fb_photo_with_invalid_align_value
    assert_raises(ArgumentError) {@h.fb_photo("1234", :align => :rightt)}
  end

  def test_fb_photo_with_valid_align_value
    assert_equal "<fb:photo align=\"right\" pid=\"1234\" />",@h.fb_photo("1234", :align => :right)
  end

  def test_fb_photo_with_class
    assert_equal "<fb:photo class=\"picky\" pid=\"1234\" />",@h.fb_photo("1234", :class => :picky)
  end
  def test_fb_photo_with_style
    assert_equal "<fb:photo pid=\"1234\" style=\"some=css;put=here;\" />",@h.fb_photo("1234", :style => "some=css;put=here;")
  end
  
  def test_fb_prompt_permission_valid_no_callback
    assert_equal "<fb:prompt-permission perms=\"email\">Can I email you?</fb:prompt-permission>",@h.fb_prompt_permission("email","Can I email you?")    
  end
  
  def test_fb_prompt_permission_valid_with_callback
    assert_equal "<fb:prompt-permission next_fbjs=\"do_stuff()\" perms=\"email\">a message</fb:prompt-permission>",@h.fb_prompt_permission("email","a message","do_stuff()")
  end
  
  def test_fb_prompt_permission_invalid_option
    assert_raises(ArgumentError) {@h.fb_prompt_permission("invliad", "a message")}
    
  end
  
  def test_fb_add_profile_section
    assert_equal "<fb:add-section-button section=\"profile\" />",@h.fb_add_profile_section
  end

  def test_fb_add_info_section
    assert_equal "<fb:add-section-button section=\"info\" />",@h.fb_add_info_section
  end

  def test_fb_name_with_invalid_key
    assert_raises(ArgumentError) {@h.fb_name(1234, :sizee => false)}
  end

  def test_fb_name
    assert_equal "<fb:name uid=\"1234\" />",@h.fb_name("1234")
  end
    
  def test_fb_name_with_transformed_key
    assert_equal "<fb:name uid=\"1234\" useyou=\"true\" />", @h.fb_name(1234, :use_you => true)
  end
  
  def test_fb_name_with_user_responding_to_facebook_id
    user = flexmock("user", :facebook_id => "5678")
    assert_equal "<fb:name uid=\"5678\" />", @h.fb_name(user)
  end
  
  def test_fb_name_with_invalid_key
    assert_raises(ArgumentError) {@h.fb_name(1234, :linkd => false)}
  end
  
  def test_fb_tabs
    assert_equal "<fb:tabs></fb:tabs>", @h.fb_tabs{}
  end
  
  def test_fb_tab_item
    assert_equal "<fb:tab-item href=\"http://www.google.com\" title=\"Google\" />", @h.fb_tab_item("Google", "http://www.google.com")
  end
  
  def test_fb_tab_item_raises_exception_for_invalid_option
    assert_raises(ArgumentError) {@h.fb_tab_item("Google", "http://www.google.com", :alignn => :right)}
  end

  def test_fb_tab_item_raises_exception_for_invalid_align_value
    assert_raises(ArgumentError) {@h.fb_tab_item("Google", "http://www.google.com", :align => :rightt)}
  end
    
  def test_fb_req_choice
    assert_equal "<fb:req-choice label=\"label\" url=\"url\" />", @h.fb_req_choice("label","url")
  end
  
  def test_fb_multi_friend_selector
    assert_equal "<fb:multi-friend-selector actiontext=\"This is a message\" max=\"20\" showborder=\"false\" />", @h.fb_multi_friend_selector("This is a message")
  end
  def test_fb_multi_friend_selector_with_options
    assert_equal "<fb:multi-friend-selector actiontext=\"This is a message\" exclude_ids=\"1,2\" max=\"20\" showborder=\"false\" />", @h.fb_multi_friend_selector("This is a message",:exclude_ids=>"1,2")
  end

  def test_fb_comments
    assert_equal "<fb:comments candelete=\"false\" canpost=\"true\" numposts=\"7\" showform=\"true\" xid=\"a:1\" />", @h.fb_comments("a:1",true,false,7,:showform=>true)
  end
  
  def test_fb_title
    assert_equal "<fb:title>This is the canvas page window title</fb:title>", @h.fb_title("This is the canvas page window title")
  end
  
  def test_fb_google_analytics
    assert_equal "<fb:google-analytics uacct=\"UA-9999999-99\" />", @h.fb_google_analytics("UA-9999999-99")
  end

  def test_fb_if_is_user_with_single_object
    user = flexmock("user", :facebook_id => "5678")
    assert_equal "<fb:if-is-user uid=\"5678\"></fb:if-is-user>", @h.fb_if_is_user(user){}    
  end
  
  def test_fb_if_is_user_with_array
    user1 = flexmock("user", :facebook_id => "5678")
    user2 = flexmock("user", :facebook_id => "1234")
    assert_equal "<fb:if-is-user uid=\"5678,1234\"></fb:if-is-user>", @h.fb_if_is_user([user1,user2]){}
  end
  
  def test_fb_else
    assert_equal "<fb:else></fb:else>", @h.fb_else{}    
  end
  
  def test_fb_about_url
    ENV["FACEBOOK_API_KEY"]="1234"
    assert_equal "http://www.facebook.com/apps/application.php?api_key=1234", @h.fb_about_url
  end
  
  def test_fb_ref_with_url
    assert_equal "<fb:ref url=\"A URL\" />", @h.fb_ref(:url => "A URL")
  end
  
  def test_fb_ref_with_handle
    assert_equal "<fb:ref handle=\"A Handle\" />", @h.fb_ref(:handle => "A Handle")
  end
  
  def test_fb_ref_with_invalid_attribute
    assert_raises(ArgumentError) {@h.fb_ref(:handlee => "A HANLDE")}
  end
  
  def test_fb_ref_with_handle_and_url
    assert_raises(ArgumentError) {@h.fb_ref(:url => "URL", :handle => "HANDLE")}
  end  
  
  def test_facebook_messages_notice
    @h.flash[:notice]="A message"
    assert_equal "<fb:success message=\"A message\" />",@h.facebook_messages
  end
  
  def test_facebook_messages_error
    @h.flash[:error]="An error"
    assert_equal "<fb:error message=\"An error\" />",@h.facebook_messages
  end
  def test_fb_wall_post
    assert_equal "<fb:wallpost uid=\"1234\">A wall post</fb:wallpost>",@h.fb_wall_post("1234","A wall post")
  end
  
  def test_fb_pronoun
    assert_equal "<fb:pronoun uid=\"1234\" />", @h.fb_pronoun(1234)
  end
  
  def test_fb_pronoun_with_transformed_key
    assert_equal "<fb:pronoun uid=\"1234\" usethey=\"true\" />", @h.fb_pronoun(1234, :use_they => true)
  end
  
  def test_fb_pronoun_with_user_responding_to_facebook_id
    user = flexmock("user", :facebook_id => "5678")
    assert_equal "<fb:pronoun uid=\"5678\" />", @h.fb_pronoun(user)
  end
  
  def test_fb_pronoun_with_invalid_key
    assert_raises(ArgumentError) {@h.fb_pronoun(1234, :posessive => true)}
  end
  
  def test_fb_wall
    @h.expects(:capture).returns("wall content")
    @h.fb_wall do 
    end
    assert_equal "<fb:wall>wall content</fb:wall>",_erbout
  end
  
  def test_fb_multi_friend_request
    @h.expects(:capture).returns("body")
    @h.expects(:protect_against_forgery?).returns(false)
    @h.expects(:fb_multi_friend_selector).returns("friend selector")
    assert_equal "<fb:request-form action=\"action\" content=\"body\" invite=\"true\" method=\"post\" type=\"invite\">friend selector</fb:request-form>",
      (@h.fb_multi_friend_request("invite","ignored","action") {})
  end
  
  def test_fb_multi_friend_request_with_protection_against_forgery
    @h.expects(:capture).returns("body")
    @h.expects(:protect_against_forgery?).returns(true)
    @h.expects(:request_forgery_protection_token).returns('forgery_token')
    @h.expects(:form_authenticity_token).returns('form_token')

    @h.expects(:fb_multi_friend_selector).returns("friend selector")
    assert_equal "<fb:request-form action=\"action\" content=\"body\" invite=\"true\" method=\"post\" type=\"invite\">friend selector<input name=\"forgery_token\" type=\"hidden\" value=\"form_token\" /></fb:request-form>",
      (@h.fb_multi_friend_request("invite","ignored","action") {})
  end
  
  def test_fb_dialog
    @h.expects(:capture).returns("dialog content")
    @h.fb_dialog( "my_dialog", "1" ) do
    end
    assert_equal '<fb:dialog cancel_button="1" id="my_dialog">dialog content</fb:dialog>', _erbout
  end
  def test_fb_dialog_title
    assert_equal '<fb:dialog-title>My Little Dialog</fb:dialog-title>', @h.fb_dialog_title("My Little Dialog")
  end
  def test_fb_dialog_content
    @h.expects(:capture).returns("dialog content content")
    @h.fb_dialog_content do
    end
    assert_equal '<fb:dialog-content>dialog content content</fb:dialog-content>', _erbout
  end
  def test_fb_dialog_button
    assert_equal '<fb:dialog-button clickrewriteform="my_form" clickrewriteid="my_dialog" clickrewriteurl="http://www.some_url_here.com/dialog_return.php" type="submit" value="Yes" />',
      @h.fb_dialog_button("submit", "Yes", {:clickrewriteurl => "http://www.some_url_here.com/dialog_return.php",
                                            :clickrewriteid => "my_dialog", :clickrewriteform => "my_form" } )
  end
  
  def test_fb_request_form
    @h.expects(:capture).returns("body")
    @h.expects(:protect_against_forgery?).returns(false)
    assert_equal "<fb:request-form action=\"action\" content=\"Test Param\" invite=\"true\" method=\"post\" type=\"invite\">body</fb:request-form>",
      (@h.fb_request_form("invite","test_param","action") {})
  end

  def test_fb_request_form_with_protect_against_forgery
    @h.expects(:capture).returns("body")
    @h.expects(:protect_against_forgery?).returns(true)
    @h.expects(:request_forgery_protection_token).returns('forgery_token')
    @h.expects(:form_authenticity_token).returns('form_token')
    assert_equal "<fb:request-form action=\"action\" content=\"Test Param\" invite=\"true\" method=\"post\" type=\"invite\">body<input name=\"forgery_token\" type=\"hidden\" value=\"form_token\" /></fb:request-form>",
      (@h.fb_request_form("invite","test_param","action") {})
  end
  
  def test_fb_error_with_only_message
    assert_equal "<fb:error message=\"Errors have occurred!!\" />", @h.fb_error("Errors have occurred!!")
  end

  def test_fb_error_with_message_and_text
    assert_equal "<fb:error><fb:message>Errors have occurred!!</fb:message>Label can't be blank!!</fb:error>", @h.fb_error("Errors have occurred!!", "Label can't be blank!!")
  end

  def test_fb_explanation_with_only_message
    assert_equal "<fb:explanation message=\"This is an explanation\" />", @h.fb_explanation("This is an explanation")
  end

  def test_fb_explanation_with_message_and_text
    assert_equal "<fb:explanation><fb:message>This is an explanation</fb:message>You have a match</fb:explanation>", @h.fb_explanation("This is an explanation", "You have a match")
  end

  def test_fb_success_with_only_message
    assert_equal "<fb:success message=\"Woot!!\" />", @h.fb_success("Woot!!")
  end

  def test_fb_success_with_message_and_text
    assert_equal "<fb:success><fb:message>Woot!!</fb:message>You Rock!!</fb:success>", @h.fb_success("Woot!!", "You Rock!!")
  end
  
  def test_facebook_form_for
    @h.expects(:protect_against_forgery?).returns(false)
    form_body=@h.facebook_form_for(:model,:url=>"action") do
    end
    assert_equal "<fb:editor action=\"action\"></fb:editor>",form_body
  end
  
  def test_facebook_form_for_with_authenticity_token
    @h.expects(:protect_against_forgery?).returns(true)
    @h.expects(:request_forgery_protection_token).returns('forgery_token')
    @h.expects(:form_authenticity_token).returns('form_token')
    assert_equal "<fb:editor action=\"action\"><input name=\"forgery_token\" type=\"hidden\" value=\"form_token\" /></fb:editor>",
      (@h.facebook_form_for(:model, :url => "action") {})
  end
  
  def test_fb_friend_selector
    assert_equal("<fb:friend-selector />",@h.fb_friend_selector)
  end
  
  def test_fb_request_form_submit
    assert_equal("<fb:request-form-submit />",@h.fb_request_form_submit)  
  end   

	def test_fb_request_form_submit_with_uid
    assert_equal("<fb:request-form-submit uid=\"123456789\" />",@h.fb_request_form_submit({:uid => "123456789"}))
  end

  def test_fb_request_form_submit_with_label
    assert_equal("<fb:request-form-submit label=\"Send Invite to Joel\" />",@h.fb_request_form_submit({:label => "Send Invite to Joel"}))
  end

  def test_fb_request_form_submit_with_uid_and_label
    assert_equal("<fb:request-form-submit label=\"Send Invite to Joel\" uid=\"123456789\" />",@h.fb_request_form_submit({:uid =>"123456789", :label => "Send Invite to Joel"}))
  end
  
  def test_fb_action
    assert_equal "<fb:action href=\"/growingpets/rub\">Rub my pet</fb:action>", @h.fb_action("Rub my pet", "/growingpets/rub")  
  end
  
  def test_fb_help
    assert_equal "<fb:help href=\"http://www.facebook.com/apps/application.php?id=6236036681\">Help</fb:help>", @h.fb_help("Help", "http://www.facebook.com/apps/application.php?id=6236036681")      
  end
  
  def test_fb_create_button
    assert_equal "<fb:create-button href=\"/growingpets/invite\">Invite Friends</fb:create-button>", @h.fb_create_button('Invite Friends', '/growingpets/invite')
  end
  def test_fb_comments
    assert_equal "<fb:comments candelete=\"false\" canpost=\"true\" numposts=\"4\" optional=\"false\" xid=\"xxx\"></fb:comments>", @h.fb_comments("xxx",true,false,4,:optional=>false) 
  end
  def test_fb_comments_with_title
    assert_equal "<fb:comments candelete=\"false\" canpost=\"true\" numposts=\"4\" optional=\"false\" xid=\"xxx\"><fb:title>TITLE</fb:title></fb:comments>", @h.fb_comments("xxx",true,false,4,:optional=>false, :title => "TITLE") 
  end
  def test_fb_board
    assert_equal "<fb:board optional=\"false\" xid=\"xxx\" />", @h.fb_board("xxx",:optional => false) 
  end
  
  def test_fb_dashboard
    @h.expects(:capture).returns("dashboard content")
    @h.fb_dashboard do 
    end
    assert_equal "<fb:dashboard>dashboard content</fb:dashboard>", _erbout
  end
  def test_fb_dashboard_non_block
    assert_equal "<fb:dashboard></fb:dashboard>", @h.fb_dashboard
  end
  
  def test_fb_wide
    @h.expects(:capture).returns("wide profile content")
    @h.fb_wide do
    end
    assert_equal "<fb:wide>wide profile content</fb:wide>", _erbout
  end
  
  def test_fb_narrow
    @h.expects(:capture).returns("narrow profile content")
    @h.fb_narrow do
    end
    assert_equal "<fb:narrow>narrow profile content</fb:narrow>", _erbout
  end  
end
class TestModel
  attr_accessor :name,:facebook_id
end

class RailsFacebookFormbuilderTest < Test::Unit::TestCase
  class TestTemplate
    include ActionView::Helpers::TextHelper
    include ActionView::Helpers::CaptureHelper
    include ActionView::Helpers::TagHelper
    include Facebooker::Rails::Helpers
    attr_accessor :_erbout
    def initialize
      @_erbout=""
    end
  end
  def setup
    @_erbout = ""
    @test_model = TestModel.new
    @test_model.name="Mike"
    @template = TestTemplate.new
    @proc = Proc.new {}
    @form_builder = Facebooker::Rails::FacebookFormBuilder.new(:test_model,@test_model,@template,{},@proc)
    def @form_builder._erbout
      ""
    end
    
  end
  
  def test_text_field
    assert_equal "<fb:editor-text id=\"test_model_name\" label=\"Name\" name=\"test_model[name]\" value=\"Mike\"></fb:editor-text>",
        @form_builder.text_field(:name)
  end
  def test_text_area
    assert_equal "<fb:editor-textarea id=\"test_model_name\" label=\"Name\" name=\"test_model[name]\">Mike</fb:editor-textarea>",
        @form_builder.text_area(:name)    
  end
  
  def test_default_name_and_id
    assert_equal "<fb:editor-text id=\"different_id\" label=\"Name\" name=\"different_name\" value=\"Mike\"></fb:editor-text>",
        @form_builder.text_field(:name, {:name => 'different_name', :id => 'different_id'})
  end
  
  def test_collection_typeahead
    flexmock(@form_builder) do |fb|
      fb.should_receive(:collection_typeahead_internal).with(:name,["ABC"],:size,:to_s,{})
    end
    @form_builder.collection_typeahead(:name,["ABC"],:size,:to_s)        
  end
  
  def test_collection_typeahead_internal
    assert_equal "<fb:typeahead-input id=\"test_model_name\" name=\"test_model[name]\" value=\"Mike\"><fb:typeahead-option value=\"3\">ABC</fb:typeahead-option></fb:typeahead-input>",
      @form_builder.collection_typeahead_internal(:name,["ABC"],:size,:to_s)        
  end
  
  def test_buttons
    @form_builder.expects(:create_button).with(:first).returns("first")
    @form_builder.expects(:create_button).with(:second).returns("second")
    @template.expects(:content_tag).with("fb:editor-buttonset","firstsecond")
    @form_builder.buttons(:first,:second)    
  end
  
  def test_create_button
    assert_equal "<fb:editor-button name=\"commit\" value=\"first\"></fb:editor-button>",@form_builder.create_button(:first)
  end
  
  def test_custom
    @template.expects(:password_field).returns("password_field")
    assert_equal "<fb:editor-custom label=\"Name\"></fb:editor-custom>",@form_builder.password_field(:name)
  end
  
  def test_text
    assert_equal "<fb:editor-custom label=\"custom\">Mike</fb:editor-custom>",@form_builder.text("Mike",:label=>"custom")
  end
  
  def test_multi_friend_input
    assert_equal "<fb:editor-custom label=\"Friends\"></fb:editor-custom>",@form_builder.multi_friend_input
  end
end

class RailsPrettyErrorsTest < Test::Unit::TestCase
  def setup
    ENV['FACEBOOK_API_KEY'] = '1234567'
    ENV['FACEBOOK_SECRET_KEY'] = '7654321'
    @controller = ControllerWhichFails.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller.stubs(:verify_signature).returns(true)
  end
  
  def test_pretty_errors
    Facebooker.facebooker_config.stubs(:pretty_errors).returns(false)
    post :pass, example_rails_params_including_fb
    assert_response :success    
    post :fail, example_rails_params_including_fb
    assert_response :error
    Facebooker.facebooker_config.stubs(:pretty_errors).returns(true)
    post :pass, example_rails_params_including_fb
    assert_response :success    
    post :fail, example_rails_params_including_fb
    assert_response :error
  end
  private
    def example_rails_params_including_fb
      {"fb_sig_time"=>"1186588275.5988", "fb_sig"=>"7371a6400329b229f800a5ecafe03b0a", "action"=>"index", "fb_sig_in_canvas"=>"1", "fb_sig_session_key"=>"c452b5d5d60cbd0a0da82021-744961110", "controller"=>"controller_which_requires_facebook_authentication", "fb_sig_expires"=>"0", "fb_sig_friends"=>"417358,702720,1001170,1530839,3300204,3501584,6217936,9627766,9700907,22701786,33902768,38914148,67400422,135301144,157200364,500103523,500104930,500870819,502149612,502664898,502694695,502852293,502985816,503254091,504510130,504611551,505421674,509229747,511075237,512548373,512830487,517893818,517961878,518890403,523589362,523826914,525812984,531555098,535310228,539339781,541137089,549405288,552706617,564393355,564481279,567640762,568091401,570201702,571469972,573863097,574415114,575543081,578129427,578520568,582262836,582561201,586550659,591631962,592318318,596269347,596663221,597405464,599764847,602995438,606661367,609761260,610544224,620049417,626087078,628803637,632686250,641422291,646763898,649678032,649925863,653288975,654395451,659079771,661794253,665861872,668960554,672481514,675399151,678427115,685772348,686821151,687686894,688506532,689275123,695551670,710631572,710766439,712406081,715741469,718976395,719246649,722747311,725327717,725683968,725831016,727580320,734151780,734595181,737944528,748881410,752244947,763868412,768578853,776596978,789728437,873695441", "fb_sig_added"=>"0", "fb_sig_api_key"=>"b6c9c857ac543ca806f4d3187cd05e09", "fb_sig_user"=>"744961110", "fb_sig_profile_update_time"=>"1180712453"}
    end
  
end

# rescue LoadError
#   $stderr.puts "Couldn't find action controller.  That's OK.  We'll skip it."
end
