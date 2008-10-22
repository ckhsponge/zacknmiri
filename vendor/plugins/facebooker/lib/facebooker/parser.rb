require 'rexml/document'
require 'facebooker/session'
module Facebooker
  class Parser
    
    module REXMLElementExtensions
      def text_value
        self.children.first.to_s.strip
      end
    end
    
    ::REXML::Element.__send__(:include, REXMLElementExtensions)
    
    def self.parse(method, data)
      Errors.process(data)
      parser = Parser::PARSERS[method]
      parser.process(
        data
      )
    end
    
    def self.array_of(response_element, element_name)
      values_to_return = []
      response_element.elements.each(element_name) do |element|
        values_to_return << yield(element)
      end
      values_to_return
    end
    
    def self.array_of_text_values(response_element, element_name)
      array_of(response_element, element_name) do |element|
        element.text_value
      end
    end

    def self.array_of_hashes(response_element, element_name)
      array_of(response_element, element_name) do |element|
        hashinate(element)
      end
    end
    
    def self.element(name, data)
      data = data.body rescue data # either data or an HTTP response
      doc = REXML::Document.new(data)
      doc.elements.each(name) do |element|
        return element
      end
      raise "Element #{name} not found in #{data}"
    end
    
    def self.hash_or_value_for(element)
      if element.children.size == 1 && element.children.first.kind_of?(REXML::Text)
        element.text_value
      else
        hashinate(element)
      end
    end
    
    def self.hashinate(response_element)
      response_element.children.reject{|c| c.kind_of? REXML::Text}.inject({}) do |hash, child|
        hash[child.name] = if child.children.size == 1 && child.children.first.kind_of?(REXML::Text)
          anonymous_field_from(child, hash) || child.text_value
        else
          if child.attributes['list'] == 'true'
            child.children.reject{|c| c.kind_of? REXML::Text}.map do |subchild| 
                hash_or_value_for(subchild)
            end     
          else
            child.children.reject{|c| c.kind_of? REXML::Text}.inject({}) do |subhash, subchild|
              subhash[subchild.name] = hash_or_value_for(subchild)
              subhash
            end
          end
        end
        hash
      end      
    end
    
    def self.anonymous_field_from(child, hash)
      if child.name == 'anon'
        (hash[child.name] || []) << child.text_value
      end
    end
    
  end  
  
  class CreateToken < Parser#:nodoc:
    def self.process(data)
      element('auth_createToken_response', data).text_value
    end
  end
  
  class RegisterUsers < Parser
    def self.process(data)
      array_of_text_values(element("connect_registerUsers_response", data), "connect_registerUsers_response_elt")
    end
  end

  class GetSession < Parser#:nodoc:
    def self.process(data)      
      hashinate(element('auth_getSession_response', data))
    end
  end
  
  class GetFriends < Parser#:nodoc:
    def self.process(data)
      array_of_text_values(element('friends_get_response', data), 'uid')
    end
  end
  
  class FriendListsGet < Parser#:nodoc:
    def self.process(data)
      array_of_hashes(element('friends_getLists_response', data), 'friendlist')
    end
  end
 
  class UserInfo < Parser#:nodoc:
    def self.process(data)
      array_of_hashes(element('users_getInfo_response', data), 'user')
    end
  end
  
  class UserStandardInfo < Parser#:nodoc:
    def self.process(data)
      array_of_hashes(element('users_getStandardInfo_response', data), 'standard_user_info')
    end
  end
  
  class GetLoggedInUser < Parser#:nodoc:
    def self.process(data)
      Integer(element('users_getLoggedInUser_response', data).text_value)
    end
  end

  class PagesIsAdmin < Parser#:nodoc:
    def self.process(data)
      element('pages_isAdmin_response', data).text_value == '1'
    end
  end

  class PagesGetInfo < Parser#:nodoc:
    def self.process(data)
      array_of_hashes(element('pages_getInfo_response', data), 'page')
    end
  end

  class PublishStoryToUser < Parser#:nodoc:
    def self.process(data)
      element('feed_publishStoryToUser_response', data).text_value
    end
  end

  class RegisterTemplateBundle < Parser#:nodoc:
    def self.process(data)
      element('feed_registerTemplateBundle_response', data).text_value.to_i
    end
  end

  class GetRegisteredTemplateBundles < Parser
    def self.process(data)
      array_of_hashes(element('feed_getRegisteredTemplateBundles_response',data), 'template_bundle')
    end
  end

  class DeactivateTemplateBundleByID < Parser#:nodoc:
    def self.process(data)
      element('feed_deactivateTemplateBundleByID_response', data).text_value == '1'
    end
  end

  class PublishUserAction < Parser#:nodoc:
    def self.process(data)
      element('feed_publishUserAction_response', data).children[1].text_value == "1"
    end
  end
  
  class PublishActionOfUser < Parser#:nodoc:
    def self.process(data)
      element('feed_publishActionOfUser_response', data).text_value
    end
  end
    
  class PublishTemplatizedAction < Parser#:nodoc:
    def self.process(data)
      element('feed_publishTemplatizedAction_response', data).children[1].text_value
    end
  end
  
  class SetAppProperties < Parser#:nodoc:
    def self.process(data)
      element('admin_setAppProperties_response', data).text_value
    end
  end  
  
  class GetAppProperties < Parser#:nodoc:
    def self.process(data)
      element('admin_getAppProperties_response', data).text_value
    end
  end
  
  class GetAllocation < Parser#:nodoc:
    def self.process(data)
      element('admin_getAllocation_response', data).text_value
    end
  end
  
  class BatchRun < Parser #:nodoc:
    class << self
      def current_batch=(current_batch)
        Thread.current[:facebooker_current_batch]=current_batch
      end
      def current_batch
        Thread.current[:facebooker_current_batch]
      end
    end
    def self.process(data)
      array_of_text_values(element('batch_run_response',data),"batch_run_response_elt").each_with_index do |response,i|
        batch_request=current_batch[i]
        body=Struct.new(:body).new
        body.body=CGI.unescapeHTML(response)
        begin
          batch_request.result=Parser.parse(batch_request.method,body)
        rescue Exception=>ex
          batch_request.exception_raised=ex
        end
      end
    end
  end
  
  class GetAppUsers < Parser#:nodoc:
    def self.process(data)
      array_of_text_values(element('friends_getAppUsers_response', data), 'uid')
    end
  end
  
  class NotificationsGet < Parser#:nodoc:
    def self.process(data)
      hashinate(element('notifications_get_response', data))
    end
  end
  
  class NotificationsSend < Parser#:nodoc:
    def self.process(data)
      element('notifications_send_response', data).text_value
    end
  end 

  class NotificationsSendEmail < Parser#:nodoc:
    def self.process(data)  
      element('notifications_sendEmail_response', data).text_value
    end
  end

  class GetTags < Parser#nodoc:
    def self.process(data)
      array_of_hashes(element('photos_getTags_response', data), 'photo_tag')
    end
  end
  
  class AddTags < Parser#nodoc:
    def self.process(data)
      element('photos_addTag_response', data)
    end
  end

  class GetPhotos < Parser#nodoc:
    def self.process(data)
      array_of_hashes(element('photos_get_response', data), 'photo')
    end
  end
  
  class GetAlbums < Parser#nodoc:
    def self.process(data)
      array_of_hashes(element('photos_getAlbums_response', data), 'album')
    end
  end
  
  class CreateAlbum < Parser#:nodoc:
    def self.process(data)
      hashinate(element('photos_createAlbum_response', data))
    end
  end  
  
  class UploadPhoto < Parser#:nodoc:
    def self.process(data)
      hashinate(element('photos_upload_response', data))
    end
  end
  
  class SendRequest < Parser#:nodoc:
    def self.process(data)
      element('notifications_sendRequest_response', data).text_value
    end
  end
  
  class ProfileFBML < Parser#:nodoc:
    def self.process(data)
      element('profile_getFBML_response', data).text_value
    end
  end
  
  class ProfileFBMLSet < Parser#:nodoc:
    def self.process(data)
      element('profile_setFBML_response', data).text_value
    end
  end
  
  class ProfileInfo < Parser#:nodoc:
    def self.process(data)
      hashinate(element('profile_getInfo_response info_fields', data))
    end
  end
  
  class ProfileInfoSet < Parser#:nodoc:
    def self.process(data)
      element('profile_setInfo_response', data).text_value
    end
  end
  
  class FqlQuery < Parser#nodoc
    def self.process(data)
      root = element('fql_query_response', data)
      first_child = root.children.reject{|c| c.kind_of?(REXML::Text)}.first
      first_child.nil? ? [] : [first_child.name, array_of_hashes(root, first_child.name)]
    end
  end
  
  class SetRefHandle < Parser#:nodoc:
    def self.process(data)
      element('fbml_setRefHandle_response', data).text_value
    end
  end
  
  class RefreshRefURL < Parser#:nodoc:
    def self.process(data)
      element('fbml_refreshRefUrl_response', data).text_value
    end
  end
  
  class RefreshImgSrc < Parser#:nodoc:
    def self.process(data)
      element('fbml_refreshImgSrc_response', data).text_value
    end
  end
  
  class SetCookie < Parser#:nodoc:
    def self.process(data)
      element('data_setCookie_response', data).text_value
    end
  end
  
  class GetCookies < Parser#:nodoc:
    def self.process(data)
      array_of_hashes(element('data_getCookie_response', data), 'cookies')
    end
  end
  
  class EventsGet < Parser#:nodoc:
    def self.process(data)
      array_of_hashes(element('events_get_response', data), 'event')
    end
  end
  
  class GroupGetMembers < Parser#:nodoc:
    def self.process(data)
      root = element('groups_getMembers_response', data)
      result = ['members', 'admins', 'officers', 'not_replied'].map do |position|
        array_of(root, position) {|element| element}.map do |element|
          array_of_text_values(element, 'uid').map do |uid|
            {:position => position}.merge(:uid => uid)
          end
        end
      end.flatten      
    end
  end
  
  class EventMembersGet < Parser#:nodoc:
    def self.process(data)
      root = element('events_getMembers_response', data)
      result = ['attending', 'declined', 'unsure', 'not_replied'].map do |rsvp_status|
        array_of(root, rsvp_status) {|element| element}.map do |element|
          array_of_text_values(element, 'uid').map do |uid|
            {:rsvp_status => rsvp_status}.merge(:uid => uid)
          end
        end
      end.flatten
    end
  end
  
  class GroupsGet < Parser#:nodoc:
    def self.process(data)
      array_of_hashes(element('groups_get_response', data), 'group')
    end
  end
  
  class AreFriends < Parser#:nodoc:
    def self.process(data)
      array_of_hashes(element('friends_areFriends_response', data), 'friend_info').inject({}) do |memo, hash|
        memo[[Integer(hash['uid1']), Integer(hash['uid2'])].sort] = are_friends?(hash['are_friends'])
        memo
      end
    end
    
    private
    def self.are_friends?(raw_value)
      if raw_value == '1'
        true
      elsif raw_value == '0'
        false
      else
        nil
      end
    end
  end
  
  class SetStatus < Parser
    def self.process(data)
      element('users_setStatus_response',data).text_value == '1'
    end
  end
    
  class Errors < Parser#:nodoc:
    EXCEPTIONS = {
      1 	=> Facebooker::Session::UnknownError,
      2 	=> Facebooker::Session::ServiceUnavailable,
      4 	=> Facebooker::Session::MaxRequestsDepleted,
      5 	=> Facebooker::Session::HostNotAllowed,
      100 => Facebooker::Session::MissingOrInvalidParameter,
      101 => Facebooker::Session::InvalidAPIKey,
      102 => Facebooker::Session::SessionExpired,
      103 => Facebooker::Session::CallOutOfOrder,
      104 => Facebooker::Session::IncorrectSignature,
      120 => Facebooker::Session::InvalidAlbumId,
      250 => Facebooker::Session::ExtendedPermissionRequired,
      321 => Facebooker::Session::AlbumIsFull,
      324 => Facebooker::Session::MissingOrInvalidImageFile,
      325 => Facebooker::Session::TooManyUnapprovedPhotosPending,
      330 => Facebooker::Session::TemplateDataMissingRequiredTokens,
      340 => Facebooker::Session::TooManyUserCalls,
      341 => Facebooker::Session::TooManyUserActionCalls,
      342 => Facebooker::Session::InvalidFeedTitleLink,
      343 => Facebooker::Session::InvalidFeedTitleLength,
      344 => Facebooker::Session::InvalidFeedTitleName,
      345 => Facebooker::Session::BlankFeedTitle,
      346 => Facebooker::Session::FeedBodyLengthTooLong,
      347 => Facebooker::Session::InvalidFeedPhotoSource,
      348 => Facebooker::Session::InvalidFeedPhotoLink,      
      330 => Facebooker::Session::FeedMarkupInvalid,
      360 => Facebooker::Session::FeedTitleDataInvalid,
      361 => Facebooker::Session::FeedTitleTemplateInvalid,
      362 => Facebooker::Session::FeedBodyDataInvalid,
      363 => Facebooker::Session::FeedBodyTemplateInvalid,
      364 => Facebooker::Session::FeedPhotosNotRetrieved,
      366 => Facebooker::Session::FeedTargetIdsInvalid,
      601 => Facebooker::Session::FQLParseError,
      602 => Facebooker::Session::FQLFieldDoesNotExist,
      603 => Facebooker::Session::FQLTableDoesNotExist,
      604 => Facebooker::Session::FQLStatementNotIndexable,
      605 => Facebooker::Session::FQLFunctionDoesNotExist,
      606 => Facebooker::Session::FQLWrongNumberArgumentsPassedToFunction,
      807 => Facebooker::Session::TemplateBundleInvalid
    }
    def self.process(data)
      response_element = element('error_response', data) rescue nil
      if response_element
        hash = hashinate(response_element)
        exception = EXCEPTIONS[Integer(hash['error_code'])] || StandardError
        raise exception.new(hash['error_msg'])
      end
    end
  end
  
  class Parser
    PARSERS = {
      'facebook.auth.createToken' => CreateToken,
      'facebook.auth.getSession' => GetSession,
      'facebook.connect.registerUsers' => RegisterUsers,
      'facebook.users.getInfo' => UserInfo,
      'facebook.users.getStandardInfo' => UserStandardInfo,
      'facebook.users.setStatus' => SetStatus,
      'facebook.users.getLoggedInUser' => GetLoggedInUser,
      'facebook.pages.isAdmin' => PagesIsAdmin,
      'facebook.pages.getInfo' => PagesGetInfo,
      'facebook.friends.get' => GetFriends,
      'facebook.friends.getLists' => FriendListsGet,
      'facebook.friends.areFriends' => AreFriends,
      'facebook.friends.getAppUsers' => GetAppUsers,
      'facebook.feed.publishStoryToUser' => PublishStoryToUser,
      'facebook.feed.publishActionOfUser' => PublishActionOfUser,
      'facebook.feed.publishTemplatizedAction' => PublishTemplatizedAction,
      'facebook.feed.registerTemplateBundle' => RegisterTemplateBundle,
      'facebook.feed.deactivateTemplateBundleByID' => DeactivateTemplateBundleByID,
      'facebook.feed.getRegisteredTemplateBundles' => GetRegisteredTemplateBundles,
      'facebook.feed.publishUserAction' => PublishUserAction,
      'facebook.notifications.get' => NotificationsGet,
      'facebook.notifications.send' => NotificationsSend,
      'facebook.notifications.sendRequest' => SendRequest,
      'facebook.profile.getFBML' => ProfileFBML,
      'facebook.profile.setFBML' => ProfileFBMLSet,
      'facebook.profile.getInfo' => ProfileInfo,
      'facebook.profile.setInfo' => ProfileInfoSet,
      'facebook.fbml.setRefHandle' => SetRefHandle,
      'facebook.fbml.refreshRefUrl' => RefreshRefURL,
      'facebook.fbml.refreshImgSrc' => RefreshImgSrc,
      'facebook.data.setCookie' => SetCookie,
      'facebook.data.getCookies' => GetCookies,
      'facebook.admin.setAppProperties' => SetAppProperties,
      'facebook.admin.getAppProperties' => GetAppProperties,
      'facebook.admin.getAllocation' => GetAllocation,
      'facebook.batch.run' => BatchRun,
      'facebook.fql.query' => FqlQuery,
      'facebook.photos.get' => GetPhotos,
      'facebook.photos.getAlbums' => GetAlbums,
      'facebook.photos.createAlbum' => CreateAlbum,
      'facebook.photos.getTags' => GetTags,
      'facebook.photos.addTag' => AddTags,
      'facebook.photos.upload' => UploadPhoto,
      'facebook.events.get' => EventsGet,
      'facebook.groups.get' => GroupsGet,
      'facebook.events.getMembers' => EventMembersGet,
      'facebook.groups.getMembers' => GroupGetMembers,
      'facebook.notifications.sendEmail' => NotificationsSendEmail
    }
  end
end
