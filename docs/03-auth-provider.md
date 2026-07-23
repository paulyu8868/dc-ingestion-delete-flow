# 03. Auth Provider

`client_credentials → core token → a360 교환` 을 수행하는 커스텀 Auth Provider.
Client Id/Secret을 따로 저장하여 하드코딩을 방지하며, 커스텀 Apex(이전에 배포한)를 통해 토큰 교환을 대신하고 `Named Credential(05)`이 그 토큰을 콜아웃에 주입한다.
(동작 원리 → [개념 §3](concept.md))

## 설정(⚙️)
1. Setup(⚙️) > **Auth Providers** > **New**
2. **Provider Type**: `DataCloudAuthProvider` (배포된 Apex 플러그인)
3. 값 입력:
   | 필드 | 값 | 설명 |
   |---|---|---|
   | Name / URL Suffix | 예 `Data360Auth` |   |
   | Token Endpoint | https://`<Current My Domain URL>`/services/oauth2/token |  Setup(⚙️) > My Domain 에서 `Current My Domain URL` 확인 필요  |
   | Client Id | Connected App(01)의 Consumer Key | Setup(⚙️) > App Manager > 대상 Connected App(▼) > View > Manage Consumer Details > `Consumer Key`|
   | Client Secret | Connected App(01)의 Consumer Secret | Setup(⚙️) > App Manager > 대상 Connected App(▼) > View > Manage Consumer Details >  `Consumer Secret`|
   | Execute As | `Manage Users	` 권한이 있는 유저 (보통 `System Administrator` Profile) | **Manage Users 권한 확인**: Setup(⚙️) > Profiles > Profile 선택 > `Administrative Permissions` 항목의 `Manage Users` 체크 여부 확인 |
   | Callback URL | 처음엔 일단 비워둠 | Callback URL은 Auth Provider 생성 후 나오는 Callback URL로 수정한다. 아래 참고.   |
   - PKCE 해제, Registration Handler 비워둠
   - **Save**
5. **Callback URL**:
   1. **Save** 후 나오는 상세 화면 →  **Callback URL**(`.../services/auth/authcallback/<Auth Provider 이름>`) 복사
      > <img width="1048" height="256" alt="image" src="https://github.com/user-attachments/assets/3034815a-5cce-4ed0-ad18-f3bc7d5ab3e6" />

   2. **Edit** → Callback URL 필드에 붙여넣고 다시 **Save**

## ⚠️ 확인
- 상세 화면에 4개 값(Token Endpoint/Client Id/Secret/Callback)이 저장돼 있는지. (특히 Edit 할때)
- 커스텀 필드는 `DataCloud_Auth_Provider__mdt`(protected) 레코드로 저장된다. 시크릿은 여기에만 존재.


관련: [개념 §3](concept.md) · 다음 → [04-remote-site](04-remote-site.md)
