extends SceneTree
## 온라인 기능 점검 (서버 없이): 서버(Python)가 만든 패치 서명을 게임이 받아들이는지, 판 기록 HMAC이 서버와 같은지.
##   godot --headless --path . -s tools/online_check.gd
## 값은 server/app/signing.py로 만든 시험용 키라 실제 서버 키와 상관없다.

const PUB := """-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtm/T5XCNg2u7687dfuse
e9ao46ZD/RlPpQLWECMKKCLW/C31CwaVBGykTjOLBCEiK3WpsvZCrkDOv80zDlwn
FpJ3GWT0/HjOflyoMZh6EmzEde0ZZHtC57GZ8fChB02GyjBceofky0jYjy4Xa0aZ
+5mvsEAG9Y6PdarT9aufOpVspWZF/GWA6b5wfvs1efQcvOrVeqjZrw5qyIigoM0+
hs4l44Pvq47AHGSVXoHpwJh7AysAudsBB4j9h9GZ8DbGhJ1VSjbM7rpZAOtEPLzp
jxmSgbeaPj0Tc8rQv0xWxGL8jYfRMDgucX+uZkYuO1xU6AtlEh4u06n7Mpjmdzzk
JwIDAQAB
-----END PUBLIC KEY-----"""
const PAYLOAD := "{\"data\":{\"elem_dmg\":{\"fire\":1.1},\"message\":\"공지 테스트\",\"perks\":{\"power\":0.2}},\"id\":7,\"max_game\":\"\",\"min_game\":\"0.0.0\"}"
const SIG := "Si0h4TB4AJmGXIBmEnGJfa3u46D9zAXH36jjnIE+k1bFZZqADUai13pwA0tD2bNYHcl/PYHQpSwnFe1bbTUa54tiCOki9TXwToTLDcnxE2ldkwy8BP+abkH72Kqi3sljM7YBED/msEDO2/uYkrzBfajLBALvWInLBbzcqkrmAEa+8MYt9Ob/5IBuN5VllHHAoScSI+ELsZp0OwetW0+GVx6t8FYdUbXZuOHDsgrDXo3EFHbmIyzG1uwJ+d6FIgZzcBu0XV5yOehzIfZEaRAx9xyD+zl3tldxfRxZk6TC1Xqbt25ICekP3ZJhXUYbVS29lEaT8PzBcZ9Jydr3QMro/g=="
const BODY := "{\"a\":1,\"nick\":\"빈두\"}"
const MAC := "7c4231a02c805b783c27cd974dbf228e66d6ff8a4e5c08d1e9231c5844d5804f"


func _init() -> void:
	var ok := true
	ok = _check("서명 맞음", Patch.verify(PAYLOAD, SIG, PUB)) and ok
	ok = _check("내용을 바꾸면 거부", not Patch.verify(PAYLOAD.replace("0.2", "9.9"), SIG, PUB)) and ok
	ok = _check("공개키 없으면 거부", not Patch.verify(PAYLOAD, SIG, "")) and ok
	var mac := Crypto.new().hmac_digest(HashingContext.HASH_SHA256, "hk".to_utf8_buffer(), BODY.to_utf8_buffer()).hex_encode()
	ok = _check("HMAC이 서버와 같음", mac == MAC) and ok
	# 적용: 패치 값이 규칙·특성·속성 배율에 들어가는지
	var j: Dictionary = JSON.parse_string(PAYLOAD)
	Patch.pending = {"id": int(j["id"]), "data": j["data"]}
	Patch.commit()
	ok = _check("패치 번호", Patch.id == 7) and ok
	ok = _check("특성 수치", is_equal_approx(Patch.num("perks", "power", 0.15), 0.2)) and ok
	ok = _check("없는 값은 기본값", is_equal_approx(Patch.num("perks", "haste", 0.12), 0.12)) and ok
	ok = _check("속성 배율", is_equal_approx(Patch.elem_mul.get(Elem.FIRE, 1.0), 1.1)) and ok
	ok = _check("공지", Patch.text("", "message", "") == "공지 테스트") and ok
	Patch.pending = {"id": 0, "data": {"rules": {"all": {"orb_hp": 1.3}, "2": {"max_mod": 4, "mod_decay": true}}}}
	Patch.commit()
	Rules.apply(2)
	ok = _check("규칙 덮어쓰기 (버전 2)", Rules.max_mod == 4 and Rules.mod_decay and is_equal_approx(Rules.orb_hp, 1.3) and Rules.max_elems == 2) and ok
	Rules.apply(1)
	ok = _check("다른 버전엔 all만", Rules.max_mod == 5 and not Rules.mod_decay and is_equal_approx(Rules.orb_hp, 1.3)) and ok
	Patch.pending = {"id": 0, "data": {}}
	Patch.commit()
	Rules.apply(1)
	ok = _check("패치 없으면 내장 값", is_equal_approx(Rules.orb_hp, 1.0) and Patch.elem_mul.is_empty()) and ok
	print("결과: ", "모두 통과" if ok else "실패 있음")
	quit(0 if ok else 1)


func _check(name: String, cond: bool) -> bool:
	print(("  통과  " if cond else "  실패  ") + name)
	return cond
