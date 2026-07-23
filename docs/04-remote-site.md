# 04. Remote Site Setting

Apex 의 **외부 콜아웃을 허용**하는 화이트리스트. Salesforce 는 기본적으로 아웃바운드 HTTP 를 막는다.
Auth Provider(03)가 토큰 엔드포인트(core/a360)로 **직접 콜아웃**하므로 그 호스트를 등록해야 한다.

> DC 호스트(`*.c360a.salesforce.com`) 콜아웃은 Named Credential(05)이 처리 → 여기 등록 불필요.
> 여기서 여는 건 **코어 도메인**뿐.

## ⚙️설정 방법
1. Setup > **Remote Site Settings** > **New Remote Site**
2. 입력:
   | 필드 | 값 | 설명 |
   |---|---|---|
   | Remote Site Name | 예 `core_domain` |   |
   | Remote Site URL | `https://<Current My Domain URL>` | Setup(⚙️) > My Domain 에서 `Current My Domain URL` 확인  |
   | Active | ✅체크 |   |
3. **Save**


## ⚠️미등록시 발생하는 증상
| 증상 | 원인 |
|---|---|
| `unauthorized endpoint` (인증/콜아웃 시) | 코어 도메인 Remote Site 누락 또는 URL 오타 |

관련: [개념 §1·§2](concept.md) · 다음 → [05-named-credential](05-named-credential.md)
