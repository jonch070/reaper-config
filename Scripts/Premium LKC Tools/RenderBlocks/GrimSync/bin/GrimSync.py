# NoIndex: true

#*******************************************************************************
# The content of this file includes portions of the LKC TOOLS GRIM SYNC Technology
# released in source code form as part of the ReaPack package.
#
# Commercial License Usage
#
# Licensees holding valid commercial licenses to the LKC TOOLS GRIM SYNC Technology
# may use this file in accordance with the end user license agreement provided
# with the software or, alternatively, in accordance with the terms contained in a
# written agreement between you and LKC TOOLS.
#
#  Copyright (c) 2025 LKC TOOLS
#*******************************************************************************/


#!/usr/bin/python
import pickle #for handling obj files
import time #for timeout when it can't connect with Wwise
import os
import json
import sys
from pprint import pprint
from typing import final
from waapi import EventHandler, connect #waapi
#---------------------------------------
WWISE_PROJECT_LOADED = False
# determine if application is a script file or frozen exe
if getattr(sys, 'frozen', False):
    script_path = os.path.dirname(sys.executable)
elif __file__:
    script_path = os.path.dirname(os.path.realpath(__file__))


def log(text):
    print(text)
    print(text, file=open(script_path + "/GrimSync.log", "a"))

    
def save_obj(obj, name ):
    with open(script_path + "/" + name + '.pkl', 'wb') as f:
        pickle.dump(obj, f, pickle.HIGHEST_PROTOCOL)

def load_obj(name ):
    with open(script_path + "/" + name + '.pkl', 'rb') as f:
        return pickle.load(f)

def connect_with_wwise(url):
    client = connect(url=url)
    while not client:
        log("Cannot connect to Wwise!")
        # os.system("pause")
        time.sleep(1)
        client = connect()
    log("Connected to Wwise!")
    return client

def disconnect_from_wwise(client):
    client.disconnect()
    log( "\nDisconnected!" )


def check_profiler(client):
    log("Getting Wwise instance information:")
    result = client.call("ak.wwise.core.getInfo")
    log( "Wwise Version: " + result["version"]["displayName"]) 
    if int(result["version"]["year"]) < 2024:
        log("Checking profiler status:",)
        args = {}
        res = client.call("ak.wwise.core.remote.getConnectionStatus",args)
        log(res)
        if res["isConnected"]:
            log("PROFILER IS CONNECTED, it must be disabled first")
            i = input("Do you want to disconnect profiler? (y/n):")
            if i == "y" or i == "Y":
                log("Disconnect profiler...")
                res = client.call("ak.wwise.core.remote.disconnect",{})
            else:
                log("ABORT")
                disconnect_from_wwise(client)
                sys.exit()
        else:
            log("PROFILER DISCONNECTED")
        
#####################################################################################################################################################
ALLOWED_HIER_TYPES = { #types allowed for creation of link region in REAPER
    "WorkUnit": True,
    "ActorMixer": True,
    "RandomSequenceContainer": True,
    "SwitchContainer": True,
    "BlendContainer": True,
    "Folder": True,
    "MusicSwitchContainer": True,
    "MusicSegment": True,
    "MusicPlaylistContainer": True,
}

def wcalculate_dynamic_path(client,guid,dynamic_config,final_path=None):
    if final_path == None:
        final_path = ""
    # print("PATH WITH TYPES:" + guid)
    args = {
        "from": {
            "id": [
                guid
            ]
        }
    }
    options = {
        "return": [
            # 'id',
            'name',
            'type',
            # 'filePath',
            'path',
            'parent'
            #"sound:originalWavFilePath"
        ]
    }

    res = client.call("ak.wwise.core.object.get",args,options=options)

    path = res['return'][0]['path']
    name = res['return'][0]['name']
    ttype =res['return'][0]['type']



    # print("-PATH:" + path)s
    # print("-NAME:" + name)
    # print("-TYPE:" + ttype)
    
    if ttype == "WorkUnit" and name == "Events": #If we are calculating link for EVENTS path
        final_path=""
        return final_path
    if name != "Actor-Mixer Hierarchy": # for all other cases, we are making dynamic path for origs and events, based on CONTAINER path in Actor-Mixer Hierarchy
        if name != "Interactive Music Hierarchy":
            if name != "Default Work Unit":
                if dynamic_config.get(ttype,False):
                    # final_path = "<" + ttype + ">" + name + "/" + final_path
                    final_path = name + "/" + final_path
                # else:
            #     final_path = name + final_path
    try:
        parentObject = res['return'][0]['parent']
        # print("-PARENT GUID:" + parentObject['id'])
        # print("-PARENT NAME:" + parentObject['name'])
        # print(final_path)
        final_path = wcalculate_dynamic_path(client,parentObject['id'],dynamic_config,final_path=final_path)
    except:
        # log("NO PARENT FOR:" + path)
        # os.system("pause")
        pass
    return final_path




def wselected(client):
    # client = connect()
    # if not client:
    # 	log("Cannot connect to Wwise!")
    # 	return
    # 	# time.sleep(1)
    # 	# client = connect()
    # log("Connected to Wwise!")

    guid = ""
    log("Getting selected object...")
    options = {}
    result = client.call("ak.wwise.ui.getSelectedObjects",options)
    # try:
    # 	log("RESULT:\t\t" + result)
    # except:
    # 	log("ERROR: Can't get selected object!")


    try:
        log("")
        name = result["objects"][0]["name"]
        log("OBJECT:\t\t" + name)
        guid = result["objects"][0]["id"]
        log("GUID:\t\t" + guid)
        args = {
            "from": {
                "id": [
                    guid
                ]
            }
        }
        options = {
            "return": [
                # 'id',
                # 'name',
                'type',   
                # 'filePath',
                'path',
                "sound:originalWavFilePath"
            ]
        }
        res = client.call("ak.wwise.core.object.get",args,options=options)
        path = res['return'][0]['path']
        path += "/"
        obj_type = res['return'][0]['type']
        
        # if not obj_type in ALLOWED_HIER_TYPES:
        #     log("Invalid object type:" + obj_type)
        
        try:
            originalWavFilePath = res['return'][0]['sound:originalWavFilePath']
        except:
            # log("NO WAV SOURCE")
            pass
        log("PATH:\t\t" + path)

        # GET PATH OF SELECTED OBJECT INCLUDING TYPES FOR ALL OBJECTS
        originals = wcalculate_dynamic_path(client,guid,ORIGINALS_CONFIG)
        print("ORIGINALS:\t" + originals)
        
        events_subpath = wcalculate_dynamic_path(client,guid,EVENTS_CONFIG)
        print("EVENTS SUBPATH:\t" + events_subpath)

        descriptive_path = wget_descriptive_path(client,guid)

        #SAVE INFORMATION TO OBJECT FILE
        try:
            log(">>>")
            log("{\"name\":" + "\"" + name + "\"},")
            log("{\"guid\":" + "\"" + guid + "\"},")
            log("{\"path\":" + "\"" + path + "\"}")
            # log("{\"path\":" + "\"" + descriptive_path + "\"}")
            log("{\"type\":" + "\"" + obj_type + "\"}")
            log("{\"originals\":" + "\"" + originals + "\"}")
            log("{\"events_subpath\":" + "\"" + events_subpath + "\"}")
            
            
            try:
                log("{\"wav\":" + "\"" + originalWavFilePath + "\"}")
            except:
                pass
            log("<<<")
            # save_obj(name,"wwise_object_name")
            # save_obj(guid,"wwise_object_guid")
            # save_obj(path,"wwise_object_path")
            log("INFORMATION OBJECTS SAVED!")
        except:
            log("ERROR:Could not write information about selected objects!")
            os.system("pause")

    except:
        log("ERROR Detecting selected object!")
        os.system("pause")

    # client.disconnect()
    log( "PROCESS COMPLETED!" )

#####################################################################################################################################################################
def wimport(client):
    try:
        with open(script_path + "/grim_audio_to_import.json") as f:
            args = json.load(f)

    except:
        log("Error loading GrimSync JSON file...")
        os.system("pause")
        

    # client = connect()
    # if not client:
    # 	log("Cannot connect to Wwise!")
    # 	return
    # 	# time.sleep(1)
    # 	# client = connect()
    # log("Connected to Wwise!")


    log("Files to import:",)
    objects_to_create = {}
    for x in args["imports"]:
        object_name = x["notes"]
        log("\t" + object_name)
        objects_to_create[object_name] = 1
    log("")

    options = {
        "return": [
            "id", 
            "name", 
            "path"
        ]
    }
    log("Starting import process...")
    
    # set automation mode to fix p4v issue WG-63863 https://www.audiokinetic.com/qa/11842/how-to-disable-process-log-in-wwise-for-perforce-operations?show=11842#q11842
    client.call("ak.wwise.debug.enableAutomationMode",{"enable" : True})
    
    res = client.call("ak.wwise.core.audio.import",args,options=options)
    
    # reset automation mode
    client.call("ak.wwise.debug.enableAutomationMode",{"enable" : False})
    # log(res)
    log("Created SFX objects:\n")
    guid_dictionary = {}
    try:
        for x in res["objects"]:
            name = x["name"]
            path = x["path"]
            if name in objects_to_create:
                guid = x["id"]
                guid_dictionary[name] = {
                    "guid": guid,
                    "path": path
                }
                
                # log(name)
                # log(guid)
                # log("")
        try:
            log(">>>")
            # save_obj(guid_dictionary,"guid_dictionary")
            log(guid_dictionary)
            log("<<<")
            
            # CREATE JSON
            with open(script_path + "/grim_audio_guid_table.json", "w") as outfile: 
                json.dump(guid_dictionary, outfile,indent=4)
            
            log("SAVED DICTIONARY")
        except:
            pass
            log("NOTHING CREATED")
            os.system("pause")
            sys.exit()
    except:
        log("ERROR WHILE GATHERING CREATED OBJECT")
        os.system("pause")
        sys.exit()
    # client.disconnect()
    # input("Press ENTER to continue...")
    log( "PROCESS COMPLETED!" )


############################################################################################
def wevents(client):
    try:
        with open(script_path + "/events_waapi_assets_list.json") as f:
            args = json.load(f)
        log("CREATING EVENTS:")
    except:
        print("Error loading events JSON file...")
        os.system("pause")
        sys.exit()
    # connect_with_wwise(url)

    log("Starting create process...")
    
    # set automation mode to fix p4v issue WG-63863 https://www.audiokinetic.com/qa/11842/how-to-disable-process-log-in-wwise-for-perforce-operations?show=11842#q11842
    client.call("ak.wwise.debug.enableAutomationMode",{"enable" : True})
    
    res = client.call("ak.wwise.core.object.create",args,{})
    
    # reset automation mode
    client.call("ak.wwise.debug.enableAutomationMode",{"enable" : False})
    
    
    log(res)
    # log("Created SFX objects:\n")

    #     log("NOTHING CREATED")
    # disconnect_from_wwise()
    # input("Press ENTER to continue...")
    log( "PROCESS COMPLETED!" )

def wtsv(client,network_path):
    location = script_path
    if network_path:
        location = network_path
        # TODO: Maybe remove '' if needed    
    log(location)
    try:
        with open(location + "/grim_events_to_create.tsv") as f:
            ff = f.read()
        log("CREATING EVENTS:")
    except:
        log("Error loading events TSV file...")
        return
        # os.system("`pause")
        # sys.exit()``
    options = {
        "return": [
            "id", 
            "name", 
            "path"
        ]
    }
    

    
    kwargs = {
        "importLanguage": "SFX", #irrelevant cause it will be used only for events
        "importOperation": "useExisting",    
        "importFile": location + "/grim_events_to_create.tsv",
        "autoAddToSourceControl": True
    }
    if ff != "":
        # set automation mode to fix p4v issue WG-63863 https://www.audiokinetic.com/qa/11842/how-to-disable-process-log-in-wwise-for-perforce-operations?show=11842#q11842
        client.call("ak.wwise.debug.enableAutomationMode",{"enable" : True})
    
        result = client.call("ak.wwise.core.audio.importTabDelimited",kwargs)
        
        # reset automation mode
        client.call("ak.wwise.debug.enableAutomationMode",{"enable" : False})
    
        log(result)
    else:
        log("No Events to create...")

######################################################################################################################################################
def wget_descriptive_path(client, guid,desc_path=None):
    if not desc_path:
        desc_path = ""
    try:
        # get parent
        args = {
            "from": {
                "id": [
                    guid
                ]
            }
        }
        options = {
            "return": [
                'id',
                'name',
                'parent',
                'type',   
                # 'filePath',
                # 'path',
                # "sound:originalWavFilePath"
            ]
        }
        
        
        res = client.call("ak.wwise.core.object.get",args,options=options)
        id = res['return'][0]['id']
        name = res['return'][0]['name']
        type = res['return'][0]['type']
        
        desc_path = "<" + type + ">" + name + "/" + desc_path
        
        try:
            parent_id = res['return'][0]['parent']['id']
            desc_path = wget_descriptive_path(client,parent_id,desc_path=desc_path)
        except:
            print("You have reached the top of hierarchy")
            desc_path = "/" + desc_path
            pass
    except:
        log("There was an error calculating hierarchy")
        pass
    return desc_path


def validate_object_by_guid(client, guid):

    log("Validating object:" + guid)
    try:
        log("")
        args = {
            "from": {
                "id": [
                    guid
                ]
            }
        }
        options = {
            "return": [
                # 'id',
                'name',
                'type',   
                # 'filePath',
                'path',
                # "sound:originalWavFilePath"
            ]
        }
        res = client.call("ak.wwise.core.object.get",args,options=options)
        name = res['return'][0]['name']
        path = res['return'][0]['path']
        path += "/"
        obj_type = res['return'][0]['type']
        
        log("OBJECT:\t\t" + name)
        log("GUID:\t\t" + guid)
        # if not obj_type in ALLOWED_HIER_TYPES:
        #     log("Invalid object type:" + obj_type)
        
        try:
            originalWavFilePath = res['return'][0]['sound:originalWavFilePath']
        except:
            # log("NO WAV SOURCE")
            pass
        log("PATH:\t\t" + path)

        # GET PATH OF SELECTED OBJECT INCLUDING TYPES FOR ALL OBJECTS
        originals = wcalculate_dynamic_path(client,guid,ORIGINALS_CONFIG)
        print("ORIGINALS:\t" + originals)
        
        events_subpath = wcalculate_dynamic_path(client,guid,EVENTS_CONFIG)
        print("EVENTS SUBPATH:\t" + events_subpath)

        descriptive_path = wget_descriptive_path(client,guid)

        #SAVE INFORMATION TO OBJECT FILE
        return False, name, path, originals, events_subpath, obj_type
        # try:
            # log(">>>")
            # log("{\"name\":" + "\"" + name + "\"},")
            # log("{\"guid\":" + "\"" + guid + "\"},")
            # log("{\"path\":" + "\"" + path + "\"}")
            # # log("{\"path\":" + "\"" + descriptive_path + "\"}")
            # log("{\"type\":" + "\"" + obj_type + "\"}")
            # log("{\"originals\":" + "\"" + originals + "\"}")
            # log("{\"events_subpath\":" + "\"" + events_subpath + "\"}")
            
            # log("INFORMATION OBJECTS SAVED!")
        # except:
        #     log("ERROR:Could not write information about selected objects!")
        #     os.system("pause")

    except:
        log("ERROR finding object by guid:" + guid)
        return True, None, None, None, None, None #ERROR
        # os.system("pause")

def validate(client):
    try:
        with open(script_path + "/grim_data_to_validate.json") as f:
            data_to_validate = json.load(f)
    except:
        log("Error loading 'data_to_validate' JSON file...")
        os.system("pause")

    validation_results = {}
    validation_results["regions"] = {}
    validation_results["tracks"] = {}
    validation_results["blocks"] = {}

    try:
        log("Checking regions:")
        for reg_id in data_to_validate["regions"]:
            guid = data_to_validate["regions"][reg_id]["container_guid"]
            
            print(reg_id)
            print()

            err,object_name,path,originals_subpath,events_subpath,obj_type = validate_object_by_guid(client,guid)
            validation_results["regions"][reg_id] = {}
            if err:
                validation_results["regions"][reg_id]["error"] = True
            else:
                validation_results["regions"][reg_id]["error"] = False
                validation_results["regions"][reg_id]["name"] = object_name
                validation_results["regions"][reg_id]["path"] = path
                validation_results["regions"][reg_id]["originals_subpath"] = originals_subpath
                validation_results["regions"][reg_id]["events_subpath"] = events_subpath
                validation_results["regions"][reg_id]["type"] = obj_type
        
        log("Checking tracks:")
        for tr_id in data_to_validate["tracks"]:
            guid = data_to_validate["tracks"][tr_id]["container_guid"]
            print(tr_id)
            print(data_to_validate["tracks"][tr_id]["container_guid"])
            print()
            validation_results["tracks"][tr_id] = {}
            err,object_name,path,originals_subpath,events_subpath,obj_type = validate_object_by_guid(client,guid)
            if err:
                validation_results["tracks"][tr_id]["error"] = True
            else:
                validation_results["tracks"][tr_id]["error"] = False
                validation_results["tracks"][tr_id]["name"] = object_name
                validation_results["tracks"][tr_id]["path"] = path
                validation_results["tracks"][tr_id]["originals_subpath"] = originals_subpath
                validation_results["tracks"][tr_id]["events_subpath"] = events_subpath
                validation_results["tracks"][tr_id]["type"] = obj_type
                
        
        log("Checking blocks:")
        for blockid in data_to_validate["blocks"]:
            guid = data_to_validate["blocks"][blockid]["chunk_guid"]
            print(blockid)
            print(guid)
            print()
            validation_results["blocks"][blockid] = {}
            err,object_name,path,originals_subpath,events_subpath,obj_type = validate_object_by_guid(client,guid)
            if err:
                validation_results["blocks"][blockid]["error"] = True
            else:
                validation_results["blocks"][blockid]["error"] = False
                validation_results["blocks"][blockid]["name"] = object_name
                validation_results["blocks"][blockid]["path"] = path
                validation_results["blocks"][blockid]["originals_subpath"] = originals_subpath
                validation_results["blocks"][blockid]["events_subpath"] = events_subpath
                validation_results["blocks"][blockid]["type"] = obj_type
        # CREATE JSON
        with open(script_path + "/grim_validation_results.json", "w") as outfile: 
            json.dump(validation_results, outfile,indent=4)
        
        log("SAVED VALIDATION RESULTS")
    except Exception as e:
        print(e)
        log("Error validating objects...")
            
    log("==============")
    print(validation_results)
    
def get_project_info(client):
    data = {
        "wproj_is_loaded" : False
    }
    if check_for_project(client):
        args = {
            "from": {
                "path": ["/Actor-Mixer Hierarchy/Default Work Unit"]
            }
        }
        options = {
            "return": ["filePath"]
            }
        res = client.call("ak.wwise.core.object.get", args, options=options)

        if res:
            dfwu = res['return'][0]['filePath']
            dfwu1 = os.path.dirname(dfwu)
            dfwu2 = os.path.dirname(dfwu1)
            data = {
                "wproj_is_loaded" : True,
                "wproj_path" : dfwu2
            }
            log("PROJECT PATH:" + dfwu2)
        else:
            log("ERROR: Project info is not found!")
    else:
        log("CANNOT GET PROJECT INFO: Project is not loaded!")

    with open(script_path + "/grim_wproj.json", "w") as outfile: # NOT REAL JSON, JUST TEXT
        json.dump(data, outfile,indent=4)

#------------------------------------------------------------------------------------------
def check_for_project(client):
    global WWISE_PROJECT_LOADED
    args = {
        "from": {
            "path": ["/Actor-Mixer Hierarchy/Default Work Unit"]
        }
    }
    options = {
        "return": [
            "filePath"
        ]
    }
    result = client.call("ak.wwise.core.object.get", args, options=options)

    if result is not None :
        log("Connected to project")
        WWISE_PROJECT_LOADED = True
    # else:
    #     log("Cannot connect to Wwise")
    #     handler = client.subscribe("ak.wwise.core.project.loaded", on_project_loaded)
        
    return result

def on_project_loaded():
    global WWISE_PROJECT_LOADED
    WWISE_PROJECT_LOADED = True
    log("Notification: Wwise project loaded")
    

    
######################################################################################################################################################
#CHECK PORT=============================================
# import socket
# sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
# result = sock.connect_ex(('127.0.0.1',8080))
# if result == 0:
#    print ("Port is open")
# else:
#    print ("Port is not open")
# sock.close()
#=======================================================


#COMMON----------------------------------------------------------
try:
    os.remove(script_path + "/GrimSync.log")
except:
    pass


#COMMON END----------------------------------------------------------

log("SCRIPT_PATH:"+script_path)

#------------------------------------------------------------------------------------------------------

log("GrimSync Client v1.05")
log("LKC TOOLS (C) 2025")
log("Arguments: command (url)")
# log ('Number of arguments:' + str(len(sys.argv)) + ' arguments.')
# log ('Argument List:'+ str(sys.argv))
# for x in range(0,(len(sys.argv))):
#     log("ARGUMENT:" + sys.argv[x])
client = None

try:
    with open(script_path + "/grim_originals_config.json") as f:
        ORIGINALS_CONFIG = json.load(f)
except Exception as e:
    log("ERROR: Can't load grim_originals_config.json, using ORIGINALS root")
    ORIGINALS_CONFIG = { }

try:
    with open(script_path + "/grim_events_config.json") as f:
        EVENTS_CONFIG = json.load(f)
except Exception as e:
    log("ERROR: Can't load grim_events_config.json, using fixed Events location")
    EVENTS_CONFIG = { }

try:
    os.remove(script_path + "/grim_wproj.json")
except:
    pass

network_path = None
try:
    if sys.argv[3]:
        network_path = sys.argv[3]
except:
    network_path = None
    log("No network path defined, using local path for events")

url = None
try:
    if sys.argv[2]:
        url = sys.argv[2]
        log("Connection URL:" + url)
except:
    url = None
    log("Default connection url")

try:
    
    if sys.argv[1] == "--import":
        log("IMPORTING AUDIO...")
        client  = connect_with_wwise(url)
        check_profiler(client)
        wimport(client)
        disconnect_from_wwise(client)
        # input("Press enter to continue...")
    # elif sys.argv[1] == "--events":
    #     log("CREATING EVENTS...")
    #     client  = connect_with_wwise(url)
    #     check_profiler(client)
    #     wevents(client)
    #     disconnect_from_wwise(client)
    #     # input("Press enter to continue...")
    elif sys.argv[1] == "--get":
        log("GETTING SELECTED WWISE OBJECT...")
        client  = connect_with_wwise(url)
        wselected(client)
        disconnect_from_wwise(client)
        # input("Press enter to continue...")
    elif sys.argv[1] == "--all":
        log("IMPORTING AUDIO AND CREATING EVENTS:")
        client  = connect_with_wwise(url)
        check_profiler(client)
        wimport(client)
        log("NOW EVENTS....")
        # wevents(client)
        wtsv(client,network_path)
        disconnect_from_wwise(client)
    elif sys.argv[1] == "--tsv":
        log("IMPORTING TSV FILE:")
        client = connect_with_wwise(url)
        check_profiler(client)
        wtsv(client,network_path)
        # Disconnect
        disconnect_from_wwise()
    elif sys.argv[1] == "--validate":
        log("VALIDATE LINKS:")
        client = connect_with_wwise(url)
        check_profiler(client)
        validate(client)
        disconnect_from_wwise()
    elif sys.argv[1] == "--project":
        log("GET PROJECT INFO:")
        client = connect_with_wwise(url)
        check_profiler(client)
        get_project_info(client)
        disconnect_from_wwise()
except:
    log("Commands:")
    log("\t--import")
    log("\t--get")
    log("\t--tsv")
    log("\t--validate")
    log("\t--project")
    log("\t--all")
    
    if client:
        disconnect_from_wwise(client)
    # os.system("pause")
    # input("...")
    

