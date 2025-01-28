extends Control


var joinable_friends_list: Array[int]
var is_querying := false


## Returns -1 if there is no valid lobby we can join.
func get_joinable_lobby(friend_id: int) -> int:
	var game_info := Steam.getFriendGamePlayed(friend_id)
	if game_info.is_empty() or game_info.id != Steam.getAppID() or game_info.lobby is String: return -1
	return game_info.lobby


func query_and_show() -> void:
	if is_querying: return
	is_querying = true
	
	$ItemList.clear()
	joinable_friends_list.clear()
	
	for i in range(0, Steam.getFriendCount()):
		var friend_id := Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_IMMEDIATE)
		if get_joinable_lobby(friend_id) == -1: continue
			
		var friend_name := Steam.getFriendPersonaName(friend_id)
		var idx: int = $ItemList.add_item(friend_name)
		joinable_friends_list.insert(idx, friend_id)
	
	is_querying = false
	G.ui_affecting_mouse_set_visible(self, true)


func _on_hide_pressed() -> void:
	G.ui_affecting_mouse_set_visible(self, false)


func _on_item_list_item_activated(index: int) -> void:
	var friend_id := joinable_friends_list[index]
	
	var lobby_id := get_joinable_lobby(friend_id)
	if lobby_id == -1: return
	
	Steam.joinLobby(lobby_id)
	G.ui_affecting_mouse_set_visible(self, false)
