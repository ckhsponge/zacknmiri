#this a test of authentication inside of a small iframe
#result: doesn't work so well
class IframeController < ApplicationController
  def index
    render :template => "/fb/index"
  end
end