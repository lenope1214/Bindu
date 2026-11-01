class_name NickFilter
## 닉네임 거르기: 남에게 보이는 이름(리더보드·멀티 방)에 욕설·혐오·운영자 사칭을 막는다 (App Store 1.2).
## 서버 server/app/reports.py BAD_WORDS와 같은 목록 (둘 다 고칠 것). 서버도 같은 규칙으로 익명 이름으로 바꾼다.

const WORDS := [
	"시발", "씨발", "씨팔", "시팔", "씨바", "ㅅㅂ", "ㅆㅂ", "ㅅㅃ", "병신", "븅신", "빙신", "ㅂㅅ", "좆", "존나", "졸라", "ㅈㄴ", "개새", "개색",
	"새끼", "ㅅㄲ", "니미", "느금", "느그애미", "니애미", "애미", "애비", "엠창", "보지", "자지", "섹스", "썅", "꺼져", "닥쳐", "지랄", "ㅈㄹ",
	"미친놈", "미친년", "또라이", "쓰레기", "창녀", "걸레", "등신", "찐따", "한남", "김치녀", "일베", "메갈", "노무현", "운지", "장애인", "틀딱", "흑형",
	"짱깨", "쪽바리", "강간", "자살", "살인", "마약", "fuck", "fuk", "fck", "shit", "bitch", "cunt", "dick", "pussy",
	"asshole", "bastard", "slut", "whore", "nigger", "nigga", "faggot", "retard", "rapist", "porn", "nazi",
	"hitler", "suicide", "운영자", "관리자", "admin"
]


## 소문자로, 한글·영문 외(띄어쓰기·기호·숫자) 지운 뒤 목록 낱말이 들어 있는지.
static func norm(s: String) -> String:
	var re := RegEx.create_from_string("[^a-z가-힣ㄱ-ㅎㅏ-ㅣ]")
	return re.sub(s.to_lower(), "", true)


static func bad(nick: String) -> bool:
	var n := norm(nick)
	if n == "":
		return false
	for w in WORDS:
		if n.contains(w):
			return true
	return false
