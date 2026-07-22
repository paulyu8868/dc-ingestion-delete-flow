# 01. Connected App (Client Credentials)

## Connected App 생성

- Setup(⚙️) > External Client Apps > Settings  > **New Connected App**

> **Basic Information**
> - Connected App Name
> - API Name
> - Contact Email

필수 정보만 입력 후 **Save**

## 세부 설정
1) Setup > **App Manager** > 대상 Connected App(▼) > **Edit**
> **API (Enable OAuth Settings)**
> - ✅**Enable OAuth Settings** 체크
>    - **Callback URL**:
>       - `http://localhost:55555/Callback`
>       - `http://localhost:55556/Callback`
>       - `http://localhost:55557/Callback`
>       - `http://localhost:55558/Callback`
>       - `http://localhost:55559/Callback`
>    - **Selected OAuth Scopes**:
>       - `Manage user data via APIs (api)`
>       - `Perform requests at any time (refresh_token, offline_access)`
>       - `Access all Data Cloud API resources (cdp_api)`
> - ✅**Enable Client Credentials Flow** 체크


**Save**

  
2) **Manage > Edit Policies**
> **OAuth Policies**
> - Permitted Users: `All users may self-authorize`


> **Client Credentials Flow**
> - **Run As** : `Data Cloud Architect` 권한이 있는 유저


**Save**

## 확인
- Run-As 유저에 `Data Cloud Architect` 권한이 있는지.
- **Enable Client Credentials** 체크 여부.
- Enable OAuth Settings 누락이 없는지.

## 트러블슈팅
| 증상 | 원인 |
|---|---|
| `no client credentials user enabled` | Client Credentials Flow / Run-As 유저 미설정 |
| 삭제 202 인데 반영 안 됨 | Run-As 유저 권한 부족(cdp_ingest_api / 삭제 권한) |

관련: [개념 §2](concept.md) · 다음 → [02-deploy-apex](02-deploy-apex.md)
