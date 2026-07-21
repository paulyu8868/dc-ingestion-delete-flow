# 03. Auth Provider

## 무엇 / 왜
`client_credentials → core token → a360 교환` 을 수행하는 커스텀 Auth Provider.
Ingestion API 는 **DC 호스트 + a360 토큰**을 요구하는데 표준 OAuth 로는 못 얻으므로,
이 Provider 가 교환을 대신하고 Named Credential(05)이 그 토큰을 콜아웃에 주입한다.
(동작 원리 → [개념 §3](concept.md))

## 방법
1. Setup > **Auth. Providers** > **New**
2. **Provider Type**: `DataCloudAuthProvider` (배포된 Apex 플러그인)
   > 📷 [스크린샷] Provider Type 선택
3. 값 입력:
   | 필드 | 값 |
   |---|---|
   | Name / URL Suffix | 예 `DataCloud` |
   | Token Endpoint | `https://<org>.develop.my.salesforce.com/services/oauth2/token` (`.develop` 포함) |
   | Client Id | Connected App(01)의 Consumer Key |
   | Client Secret | Connected App(01)의 Consumer Secret |
   | Callback URL | (아래 2-pass — 처음엔 비움) |
   - PKCE 해제, Registration Handler / Execute Registration As 비움
   > 📷 [스크린샷] 설정값 입력 화면
4. **Callback URL 은 2-pass**:
   1. Callback 비운 채 **Save** → 상세 화면의 **Callback URL**(`.../services/auth/authcallback/<이름>`) 복사
      > 📷 [스크린샷] 생성된 Callback URL
   2. **Edit** → Callback URL 필드에 붙여넣고 다시 **Save**

## 확인
- 상세 화면에 4개 값(Token Endpoint/Client Id/Secret/Callback)이 저장돼 있는지.
- 커스텀 필드는 `DataCloud_Auth_Provider__mdt`(protected) 레코드로 저장된다. 시크릿은 여기에만 존재.

## ⚠️ 가장 흔한 함정
Client Secret 은 Edit 화면에서 **빈칸으로 표시**된다. 2-pass 재저장 때 **Secret 을 다시 입력하지 않으면
사라져서**, 인증 시 `Remote_Error: The remote service returned an error`(빈 client → invalid_client) 가 난다.
→ **Edit 할 때마다 Client Id/Secret/Token Endpoint 가 채워졌는지 확인**하고 저장.

관련: [개념 §3](concept.md) · 다음 → [04-remote-site](04-remote-site.md)
