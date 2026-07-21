# 개념 / 원리

세팅 방법은 각 `docs/NN-*.md`. 이 문서는 **왜 이렇게 구성되는지**와 **Apex 코드 구조**를 다룬다.

## 1. Core 와 Data Cloud 는 별개 시스템

가장 먼저 잡아야 할 그림. Apex 가 도는 **Salesforce Core** 와 **Data Cloud** 는 **서로 다른 호스트**다.

```
┌─ Salesforce Core ─────────┐        ┌─ Data Cloud (별개 시스템) ──┐
│  *.my.salesforce.com       │        │  *.c360a.salesforce.com      │
│  - Apex 실행               │        │  - DLO / DMO                  │
│  - Auth Provider           │        │  - Ingestion / DELETE API     │
│  - Named Credential 정의   │        │                               │
└────────────────────────────┘        └───────────────────────────────┘
   Apex(Core) ──── 외부 REST 콜아웃 ────▶ Data Cloud host
```

- Apex 입장에서 Data Cloud 는 **외부 API**다(구글 API 부르는 것과 동일).
- 그래서 "내 org 이 내 org 을 부르는" 구조가 아니라, **Core → (외부) Data Cloud** 로 나가는 평범한 외부 호출이다.
- 이 때문에 **토큰 + 콜아웃 허용 + Named Credential** 같은 장치가 필요하다.

### a360 = Data Cloud
Data Cloud 의 옛 이름이 **Customer 360 Audiences (C360A)**. 그 흔적:
- 토큰 교환 엔드포인트 `/services/a360/token`, DC 호스트 `*.c360a.salesforce.com`
- 즉 **a360 토큰 = Data Cloud 접근 토큰**.

## 2. 인증 조각들의 역할 분담

전부 "a360 토큰을 발급받아 콜아웃에 붙이는" 하나의 목적이지만, 겹치지 않고 각자 다른 일을 한다.

| 구성요소 | 담당 | 한 줄 |
|---|---|---|
| **Connected App** | 누구(자격) | 토큰 발급받을 머신 계정. client id/secret + 실행 유저 |
| **Auth Provider** | 어떻게(발급 로직) | `client_credentials → core → a360` **교환을 수행하는 Apex** |
| **Named Credential** | 어디로 + 자동주입 | DC 호스트에 붙이고 콜아웃마다 **토큰을 헤더에 자동 주입** |
| **Remote Site** | 나가도 됨(허용) | Apex 가 토큰 엔드포인트로 콜아웃하는 것을 허용하는 화이트리스트 |

### 왜 하나로 안 되나
- **토큰 관리**: a360 토큰은 금방 만료 → Named Credential 이 **401 시 자동 재발급**.
- **보안**: 시크릿이 삭제 코드/로그에 노출되지 않고 **Auth Provider 설정에만 격리**.
- **재사용**: `callout:{NC}` 하나로 삭제·업서트 등 어떤 DC 콜아웃도 처리.

> 참고: Apex 안에서 직접 토큰 2단계를 호출하고 시크릿을 CMDT 평문으로 두는 **더 단순한 방법도 동작한다.**
> 다만 시크릿 노출·수동 재발급 때문에, 위 조합으로 하드닝한 것이다.

## 3. Auth Provider 동작 원리 (핵심)

"Provider Type 선택 = 토큰 발급" 이 아니다. **로직 등록**일 뿐이고, 실제 발급은 특정 시점에 일어난다.

### 프레임워크가 우리 클래스를 부르는 훅
`DataCloudAuthProvider extends Auth.AuthProviderPluginClass` 를 배포하면 커스텀 Provider Type 이 되고,
Salesforce 가 정해진 타이밍에 아래 메서드를 호출한다.

| 메서드 | SF 가 언제 호출 | 우리 구현 |
|---|---|---|
| `getCustomMetadataType()` | 설정값 넘길 때 | 설정이 담긴 CMDT 이름 반환 → SF 가 값을 config Map 으로 전달 |
| `initiate(config, state)` | 인증 시작 | Callback URL 로 **즉시 리다이렉트**(사용자 로그인 생략) |
| `handleCallback(config, state)` | 콜백 도착 | 🔑 **여기서 실제 토큰 발급**: client_credentials→core→a360 |
| `refresh(config, refreshToken)` | 저장 토큰이 401 | 재발급(같은 로직) |
| `getUserInfo(...)` | 인증 후 표시 | 최소 정보 |

### 실제 토큰이 발급된 순간 = Named Credential 저장(Start Auth Flow on Save)
```
NC 저장 ──▶ ① initiate() → Callback URL 로 리다이렉트
          ──▶ ② handleCallback() → fetchDcToken():
                   POST /services/oauth2/token (client_credentials) → core token
                   POST /services/a360/token   (교환)              → a360 토큰  ← 발급
          ──▶ ③ SF 가 그 토큰을 이 NC 에 암호화 저장
          ──▶ ④ "인증됨" 표시
```
이후 콜아웃마다 SF 가 저장 토큰을 재사용하고, 만료(401)되면 `refresh()` 로 자동 재발급한다.

### 왜 initiate→handleCallback 으로 나뉘나
이 인터페이스는 원래 **대화형 OAuth**(구글 로그인 → 콜백으로 code 복귀 → 교환)용이다.
우리는 **머신 인증**이라, `initiate` 는 로그인 대신 콜백으로 바로 리다이렉트하고,
`handleCallback` 에서 code 교환 대신 client_credentials 로 토큰을 발급하도록 **재활용**했다.
(그래서 Callback URL 설정이 필요하고 2-pass 였다.)

## 4. Apex 코드 구조 — `DataCloudIngestDelete`

Flow 가 `fm_pk` 목록을 넘기면 Ingestion DELETE 로 삭제한다. **토큰은 다루지 않는다**(NC 주입).

### 4.1 진입점·계약
```apex
@InvocableMethod public static List<Result> run(List<Request> requests)
```
- 입력 `List<Request>` — Flow 배치가 준 요청들.
- 출력은 **입력과 같은 크기**로 반환(Flow 가 레코드별로 되매핑).
- `Request`: `ids`(필수) + `sourceApi`/`objectName`/`namedCredential`(필수, 하드코딩 기본값 없음).

### 4.2 Bulkification — 타겟별 취합
Flow 는 변경분을 배치로 묶어 Invocable 을 호출한다. 모든 Request 의 `ids` 를
`source||object||nc` 타겟별로 합친 뒤 **전역 200개 청크**로 보낸다 → 배치 100건 초과에도
**콜아웃 한도(트랜잭션당 100)** 안전. (예: 250건 → 2 콜아웃)

### 4.3 콜아웃 (토큰 미취급)
```apex
String base = 'callout:' + nc + '/api/v1/ingest/sources/'
    + EncodingUtil.urlEncode(src,'UTF-8').replace('+','%20') + '/'
    + EncodingUtil.urlEncode(obj,'UTF-8').replace('+','%20');
HttpRequest r = new HttpRequest();
r.setEndpoint(base);
r.setMethod('DELETE');
r.setHeader('Content-Type','application/json');   // Authorization 없음 → NC 가 주입
r.setBody(JSON.serialize(new Map<String,Object>{ 'ids' => chunk }));
```
- `callout:{NC}` → 호스트·토큰은 NC 담당. 삭제 코드엔 토큰/시크릿이 없다.
- source/object 는 URL 인코딩(공백/특수문자 안전), `fm_pk` 의 `|`·한글·`#` 은 JSON 본문이라 안전.

### 4.4 에러/부분성공
- 청크가 202 가 아니면 즉시 `success=false` + 메시지, 그 지점에서 중단. 앞서 202 받은 건은 `accepted` 에 반영.
- 거버너: 토큰 콜아웃 0 + `ceil(총ids/200)`. 100/txn 한도 → 한 배치 ~20,000건까지.

## 5. 트리거 — 왜 Flow 인가
- Data Cloud 객체(DLO/DMO)에는 **Apex 트리거가 안 걸린다.**
- 그래서 "레코드 트리거" 역할을 **Data Cloud-Triggered Flow** 가 맡고, 실제 삭제는 Flow 가 호출하는
  Invocable Apex 가 한다. (Flow 는 DMO/CIO 에만 걸리므로 삭제-id DLO 를 DMO 로 매핑해야 한다.)
- **루프 안전**: 트리거 객체(삭제-id DMO) ≠ 삭제 대상(원본 DLO)이라 삭제가 이 Flow 를 재발동시키지 않는다.
