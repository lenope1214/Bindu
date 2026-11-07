class_name BinduViewport
extends BinduFeature
## 전장·화면 좌표와 확대·이동. 예약 콜백은 main의 순서를 따른다.

func _phone() -> bool:
	return OS.has_feature("mobile") or Meta.sim_phone


## 폰·태블릿에서 창을 놓을 UI 폭 (글자 130% 기준). 20:9 폰은 약 1060, 4:3 태블릿은 약 740
func _phone_ui_w() -> float:
	var v := session.get_viewport_rect().size
	return v.x / maxf(1.3, Meta.ui_scale) - 90.0  # 만들 때 한 번 재므로 폰 기본 130% 이상으로 잰다


func center() -> Vector2:
	return Meta.FIELD / 2.0


## 전장: 구체가 나오고 공격이 닿고 오브젝트를 놓는 곳. 화면비와 상관없이 늘 Meta.FIELD 크기 (기기마다 난이도·순위가 같게).
func arena() -> Rect2:
	return Rect2(Vector2.ZERO, Meta.FIELD)


## 지금 화면에 보이는 월드 영역. 화면이 16:9보다 길면(폰) 전장 양옆까지, 4:3이면(태블릿) 위아래까지 보인다.
func view_rect() -> Rect2:
	var session: BinduSession = self.session
	var vs := session.get_viewport_rect().size
	if session.card_dock != null and session.card_dock.active():
		return session.card_dock.world_view()
	if session.camera == null or is_equal_approx(session.view_zoom, 1.0):
		return Rect2((Meta.FIELD - vs) / 2.0, vs)
	var s := vs / session.view_zoom
	return Rect2(session.camera.position - s / 2.0, s)


## 확대하지 않았을 때 보이는 월드 영역 (확대한 화면이 이 밖으로 나가지 않게).
func full_view() -> Rect2:
	var session: BinduSession = self.session
	if session.card_dock != null and session.card_dock.active():
		return arena()
	var vs := session.get_viewport_rect().size
	return Rect2((Meta.FIELD - vs) / 2.0, vs)


## 전장 확대: ZOOM_MIN~ZOOM_MAX배, at(화면 좌표)이 가리키는 월드 점이 그 자리에 남게. 축소하면 전장을 중앙에 두고, 확대하면 전장 밖으로 이동하지 않는다.
func _zoom_to(z: float, at: Vector2) -> void:
	var session: BinduSession = self.session
	if session.card_dock != null and session.card_dock.active():
		var origin := session.card_dock.screen_board().get_center()
		var before := center() + session.view_pan + (at - origin) / (session.card_dock.fit * session.view_zoom)
		session.view_zoom = clampf(z, BinduSession.ZOOM_MIN, BinduSession.ZOOM_MAX)
		session.view_pan = before - (at - origin) / (session.card_dock.fit * session.view_zoom) - center()
		_clamp_pan()
		return
	var vs := session.get_viewport_rect().size
	var before := session.camera.position + (at - vs / 2.0) / session.view_zoom
	session.view_zoom = clampf(z, BinduSession.ZOOM_MIN, BinduSession.ZOOM_MAX)
	session.view_pan = before - (at - vs / 2.0) / session.view_zoom - center()
	_clamp_pan()


func _pan_by(screen_d: Vector2) -> void:
	var session: BinduSession = self.session
	session.view_pan -= screen_d / (session.view_zoom * (session.card_dock.fit if session.card_dock != null and session.card_dock.active() else 1.0))
	_clamp_pan()


func _clamp_pan() -> void:
	var session: BinduSession = self.session
	if session.card_dock != null and session.card_dock.active():
		session.card_dock.camera_fit()
		return
	var fv := full_view()
	var hs := (session.get_viewport_rect().size / session.view_zoom / 2.0).min(fv.size / 2.0)
	var c := center() + session.view_pan
	c.x = clampf(c.x, fv.position.x + hs.x, fv.end.x - hs.x)
	c.y = clampf(c.y, fv.position.y + hs.y, fv.end.y - hs.y)
	session.view_pan = c - center()
	if session.camera:
		session.camera.zoom = Vector2(session.view_zoom, session.view_zoom)
		session.camera.position = center() + session.view_pan


func _reset_zoom() -> void:
	var session: BinduSession = self.session
	session.view_zoom = 1.0
	session.view_pan = Vector2.ZERO
	_clamp_pan()


## 지키는 중앙 점. 회랑 맵은 화면 가운데가 아니라 구체가 오는 반대쪽 끝(문 가운데).
func core() -> Vector2:
	var c := center()
	if Meta.map_id == "line":
		c.x = Meta.FIELD.x - BinduSession.LINE_INSET if Meta.line_flip else BinduSession.LINE_INSET
	return c


## 회랑 맵: 높이 y(길 가운데 기준)에서 구체가 나오는 자리와 닿는 문 자리.
func _line_start(y: float) -> Vector2:
	return Vector2(-30.0 if Meta.line_flip else Meta.FIELD.x + 30.0, center().y + y)


func _line_end(y: float) -> Vector2:
	return Vector2(core().x, center().y + y)
