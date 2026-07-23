# 04. Remote Site Setting

Apex 의 **외부 콜아웃을 허용**하는 화이트리스트. Salesforce 는 기본적으로 아웃바운드 HTTP 를 막는다.
Auth Provider(03)가 토큰 엔드포인트(core/a360)로 **직접 콜아웃**하므로 그 호스트를 등록해야 한다.

> DC 호스트(`*.c360a.salesforce.com`) 콜아웃은 Named Credential(05)이 처리 → 여기 등록 불필요.
> 여기서 여는 건 **코어 도메인**뿐.

## 방법
1. Setup > **Remote Site Settings** > **New Remote Site**
2. 입력:
   | 필드 | 값 | 설명 |
   |---|---|---|
   | Remote Site Name | 예 `DataCloud_Core` |   |
   | Remote Site URL | `https://<org>.develop.my.salesforce.com` |   |
   | Active | 체크 |   |
   > 📷 [스크린샷] Remote Site 입력
3. **Save**

## 확인
- 목록에 코어 도메인이 Active 로 존재.

## 트러블슈팅
| 증상 | 원인 |
|---|---|
| `unauthorized endpoint` (인증/콜아웃 시) | 코어 도메인 Remote Site 누락 또는 URL 오타 |

관련: [개념 §1·§2](concept.md) · 다음 → [05-named-credential](05-named-credential.md)
