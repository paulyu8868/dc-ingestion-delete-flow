# 05. Named Credential

콜아웃 대상(DC 호스트) + 인증 방식(Auth Provider)을 묶은 정의.
Apex 가 `callout:{이름}/...` 로 부르면 **헤더에 토큰을 자동 주입**하고, 토큰 만기(401) 시 자동 재발급한다.
덕분에 삭제 Apex 코드에서는 토큰/호스트를 직접 다루지 않는다.

## ⚙️세팅 — ⚠️ "New Legacy" 로 생성
Setup > **Named Credentials** > New 버튼 옆(▼) >**New Legacy**
(그냥 `New` 는 신형 External Credential 모델이라 **Auth Provider 연결 필드가 없다.**)

| 필드 | 값 | 설명 |
|---|---|---|
| Label | 예 `Ingestion_Named_Credential` |  |
| **Name** (API) | 예 `Ingestion_Named_Credential`  | **Flow 설정 시 Apex로 넘길 API명** |
| URL | `https://<dc-host>.c360a.salesforce.com` | `아래 DC 호스트 확인법` **참고** |
| Identity Type | **Named Principal** |  |
| Authentication Protocol | **OAuth 2.0** |  |
| Authentication Provider | **DataCloudAuthProvider** (03에서 만든 것) |  |
| Scope | **비워두기** |  |
| Generate Authorization Header | ✅ |  |
| **Start Authentication Flow on Save** | ✅ |  |


## DC 호스트 확인법
> a360 토큰 응답의 `instance_url`에서 확인 가능하므로, 이전에 생성한 (03)Auth Provider 활용한다. 아래는 APEX 코드로 오그에서 직접 확인하는 방법. 


- ⚙️Setup Menu > Developer Console > Debug > **Open Execute Anonymous Window**
- 아래 코드 복사 후 `Excute` **(✅Open Log 체크)**


```APEX
DataCloud_Auth_Provider__mdt cfg = [
  SELECT Token_Endpoint__c, Client_Id__c, Client_Secret__c
  FROM DataCloud_Auth_Provider__mdt LIMIT 1
];

HttpRequest r1 = new HttpRequest();
r1.setEndpoint(cfg.Token_Endpoint__c);
r1.setMethod('POST');
r1.setHeader('Content-Type','application/x-www-form-urlencoded');
r1.setBody('grant_type=client_credentials'
  + '&client_id=' + EncodingUtil.urlEncode(cfg.Client_Id__c,'UTF-8')
  + '&client_secret=' + EncodingUtil.urlEncode(cfg.Client_Secret__c,'UTF-8'));
HttpResponse p1 = new Http().send(r1);
Map<String,Object> j1 = (Map<String,Object>)JSON.deserializeUntyped(p1.getBody());

HttpRequest r2 = new HttpRequest();
r2.setEndpoint((String)j1.get('instance_url') + '/services/a360/token');
r2.setMethod('POST');
r2.setHeader('Content-Type','application/x-www-form-urlencoded');
r2.setBody('grant_type=' + EncodingUtil.urlEncode('urn:salesforce:grant-type:external:cdp','UTF-8')
  + '&subject_token=' + EncodingUtil.urlEncode((String)j1.get('access_token'),'UTF-8')
  + '&subject_token_type=' + EncodingUtil.urlEncode('urn:ietf:params:oauth:token-type:access_token','UTF-8'));
HttpResponse p2 = new Http().send(r2);

System.debug('DC HOST >> ' + ((Map<String,Object>)JSON.deserializeUntyped(p2.getBody())).get('instance_url'));
```



<img width="1002" height="865" alt="image" src="https://github.com/user-attachments/assets/fd1b9f17-acee-400a-ba93-eb4c04b3a5bc" />

- **crtl + f**: `dc host` 부분 확인

## ✅Save 후 인증화면
> Save 하면 Auth Provider 가 `client_credentials → core → a360` 를 실행한다. 
<img width="683" height="653" alt="image" src="https://github.com/user-attachments/assets/bdf7ebf9-608e-49a1-aa82-2c45457c9602" />


- 인증 화면이 나오면 **Confirm** 클릭

<img width="1542" height="781" alt="image" src="https://github.com/user-attachments/assets/b90120a6-3028-48ba-8cd8-635f2d8897f9" />


- 성공 → Authentication Status **인증됨** 표시










## 트러블슈팅
| 증상 | 원인 / 조치 |
|---|---|
| `Remote_Error: The remote service returned an error` | Auth Provider 설정값(특히 Secret)이 비어 전달됨 → [03](03-auth-provider.md) 값 재입력 후 저장 |
| Auth Provider 필드가 안 보임 | 신형 `New` 로 만듦 → **New Legacy** 로 재생성 |
| `invalid_client` | Client Id/Secret 불일치·미저장 |

관련: [개념 §2·§3](concept.md) · 다음 → [06-triggered-flow](06-triggered-flow.md)
