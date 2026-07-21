# 05. Named Credential

## 무엇 / 왜
콜아웃 대상(DC 호스트) + 인증 방식(Auth Provider)을 묶은 정의.
Apex 가 `callout:{이름}/...` 로 부르면 **a360 토큰을 자동 주입**하고, 401 시 자동 재발급한다.
덕분에 삭제 코드는 토큰/호스트를 다루지 않는다.

## 방법 — ⚠️ "New Legacy" 로 생성
Setup > **Named Credentials** > **New Legacy**
(그냥 `New` 는 신형 External Credential 모델이라 **Auth Provider 연결 필드가 없다.**)

| 필드 | 값 |
|---|---|
| Label | 예 `DataCloud_Ingest` |
| **Name** (API) | Apex 에 넘길 이름과 **정확히 일치** (예 `DataCloud_Ingest`) |
| URL | `https://<dc-host>.c360a.salesforce.com` |
| Identity Type | **Named Principal** |
| Authentication Protocol | **OAuth 2.0** |
| Authentication Provider | **DataCloudAuthProvider** (03에서 만든 것) |
| Scope | 공란 (또는 `cdp_ingest_api`) |
| Generate Authorization Header | ✅ |
| **Start Authentication Flow on Save** | ✅ |

> 📷 [스크린샷] New Legacy 입력 화면

## 저장 = 진실의 순간
Save 하면 Auth Provider 가 `client_credentials → core → a360` 를 실행한다.
- 성공 → Authentication Status **인증됨** 표시
  > 📷 [스크린샷] 인증됨(초록) 상태
- 실패 → 에러 메시지 확인(아래)

## DC 호스트 확인법
- a360 토큰 응답의 `instance_url`, 또는 `GET https://<dc-host>/api/v1/metadata` 로 확인.
- 대개 `xxxxxxxx.c360a.salesforce.com` 형태.

## 트러블슈팅
| 증상 | 원인 / 조치 |
|---|---|
| `Remote_Error: The remote service returned an error` | Auth Provider 설정값(특히 Secret)이 비어 전달됨 → [03](03-auth-provider.md) 값 재입력 후 저장 |
| Auth Provider 필드가 안 보임 | 신형 `New` 로 만듦 → **New Legacy** 로 재생성 |
| `invalid_client` | Client Id/Secret 불일치·미저장 |

관련: [개념 §2·§3](concept.md) · 다음 → [06-triggered-flow](06-triggered-flow.md)
