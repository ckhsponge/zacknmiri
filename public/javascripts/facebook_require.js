FB_RequireFeatures(["XFBML"], function()
{
    FB.Facebook.init(window.api_key, "/connect/xd_receiver.htm");
    FB.Facebook.get_sessionState().waitUntilReady(function() { } );
});
