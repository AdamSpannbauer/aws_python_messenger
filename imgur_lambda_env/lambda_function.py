import os
import json
import requests
import pyimgur
import random

######################
# helper functions
######################
##recursively look/return for an item in dict given key
def find_item(obj, key):
    item = None
    if key in obj: return obj[key]
    for k, v in obj.items():
        if isinstance(v,dict):
            item = find_item(v, key)
            if item is not None:
                return item

##recursivley check for items in a dict given key
def keys_exist(obj, keys):
    for key in keys:
        if find_item(obj, key) is None:
            return(False)
    return(True)

##send txt via messenger to id
def send_message(send_id, msg_txt):
    params  = {"access_token": os.environ['access_token']}
    headers = {"Content-Type": "application/json"}
    data = json.dumps({"recipient": {"id": send_id},
                       "message": {"text": msg_txt}})
                       
    r = requests.post("https://graph.facebook.com/v2.6/me/messages", params=params, headers=headers, data=data)
    
    if r.status_code != 200:
        print(r.status_code)
        print(r.text)

##send attach (pic prolly) via messenger to id
def send_attachment(send_id, attach_url):
    params  = {"access_token": os.environ['access_token']}
    headers = {"Content-Type": "application/json"}
    data = json.dumps({"recipient": {
                        "id": send_id
                        },
                        "message": {
                            "attachment": {
                                "type": "image", 
                                "payload": {
                                    "url": attach_url, "is_reusable": True
                                }
                            }
                        }
    })
    r = requests.post("https://graph.facebook.com/v2.6/me/messages", params=params, headers=headers, data=data)
    if r.status_code != 200:
        print(r.status_code)
        print(r.text)

def imgur_rand_search(search_str):
    im = pyimgur.Imgur(os.environ['imgur_client_id'])
    gal_search = im.search_gallery(search_str)
    search_urls = []
    for pic in gal_search:
        if hasattr(pic, 'images'):
            for image in pic.images:
                if not image.is_nsfw:
                    search_urls.append(image.link)

    out_url = random.sample(search_urls, 1)[0]
    return(str(out_url))
#-----------------------------------------------------------

def lambda_handler(event, context):
    #debug
    print("event:" )
    print(event)
    print("context")
    print(context)
    
    #handle webhook challenge
    if keys_exist(event, ["params","querystring","hub.verify_token","hub.challenge"]):
        v_token   = str(find_item(event['hub.verify_token']))
        challenge = int(find_item(event['hub.challenge']))
        if (os.environ['verify_token'] == v_token):
            return(challenge)
            
    #handle messaging events
    if keys_exist(event, ['body-json','entry']):
        event_entry0 = event['body-json']['entry'][0]
        if keys_exist(event_entry0, ['messaging']):
            messaging_event = event_entry0['messaging'][0]
            msg_txt   = messaging_event['message']['text']
            sender_id = messaging_event['sender']['id']
            
            first_word = msg_txt.split(" ")[0]
            
            if first_word == "!echo":
                send_message(sender_id, msg_txt)
            else:
                send_attachment(sender_id, imgur_rand_search(msg_txt))
    
    return(None)
