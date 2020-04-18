import service_creds
import tweepy
import json

# Import the necessary methods from tweepy library
from tweepy.streaming import StreamListener
from tweepy import OAuthHandler
from tweepy import Stream

auth = tweepy.OAuthHandler(service_creds.twitter.consumer_key, service_creds.twitter.consumer_secret,callback=service_creds.twitter.callback)
auth.set_access_token(service_creds.twitter.access_token, service_creds.twitter.access_token_secret)

api = tweepy.API(auth)

def auth_user(auth):
    try:
        redirect_url = auth.get_authorization_url()
    except tweepy.TweepError:
        print('Error! Failed to get request token.')

    print("Please go to this URL: {}".format(redirect_url))
    verifier = input("Paste the token it gives you back here: ")

    try:
        auth.get_access_token(verifier)
    except tweepy.TweepError:
        print('Error! Failed to get access token.')

    print(auth.access_token)
    print(auth.access_token_secret)
    return auth

sam_twitter_id = api.get_user('smarter411').id
gk_twitter_id=api.get_user('gknova61').id

