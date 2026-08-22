extends SceneTree
func _init():
    var stream = load("res://assets/INTRO.mp4")
    if stream != null:
        print("MP4 LOADED")
    else:
        print("MP4 FAILED")
    quit()
