# 01. Connected App (Client Credentials)

## 무엇 / 왜
Auth Provider 가 **브라우저 로그인 없이** core token 을 발급받기 위한 머신 자격.
콜아웃은 이 App 의 **Run-As 유저 권한**으로 실행되므로, 그 유저가 삭제 권한을 가져야 실제로 지워진다.

> 이미 client_credentials 용 Connected App 이 있으면 그걸 재사용해도 된다.

## 방법
1. Setup > **App Manager** > 대상 Connected App > **Manage** (없으면 New Connected App 으로 생성)
   > 📷 [스크린샷] App Manager 목록
2. **Enable OAuth Settings** + OAuth Scopes 에 최소 `Manage Data Cloud Ingestion API data (cdp_ingest_api)`, `api` 추가
   > 📷 [스크린샷] OAuth Scopes
3. **Enable Client Credentials Flow** 체크
   > 📷 [스크린샷] Client Credentials Flow 체크
4. **Manage > Edit Policies** > *Client Credentials Flow* 의 **Run As** 유저 지정
   > 📷 [스크린샷] Run As 유저 지정
5. Consumer Key(=Client Id) / Consumer Secret(=Client Secret) 확보 → [03-auth-provider](03-auth-provider.md) 에서 사용

## 확인
- Run-As 유저에 **`cdp_ingest_api` 권한 + 대상 데이터 스트림 삭제 권한**이 있는지.
- (선택) Client Credentials 토큰이 실제 발급되는지 curl/스크립트로 사전 확인.

## 트러블슈팅
| 증상 | 원인 |
|---|---|
| `no client credentials user enabled` | Client Credentials Flow / Run-As 유저 미설정 |
| 삭제 202 인데 반영 안 됨 | Run-As 유저 권한 부족(cdp_ingest_api / 삭제 권한) |

관련: [개념 §2](concept.md) · 다음 → [02-deploy-apex](02-deploy-apex.md)
