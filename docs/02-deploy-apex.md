# 02. Apex 배포 (VS Code)

```
force-app/main/default/classes/DataCloudIngestDelete.cls   (+ Test)   Invocable 삭제
force-app/main/default/classes/DataCloudAuthProvider.cls   (+ Test)   core→a360 토큰 교환
force-app/main/default/objects/DataCloud_Auth_Provider__mdt/          Auth Provider 설정 CMDT
```

VS Code로 **git clone → org 인증 → 배포**까지 진행한다. (익스텐션·CLI 설치 포함)

---

## 1) Salesforce CLI 설치
- [Salesforce CLI 설치 페이지](https://developer.salesforce.com/tools/salesforcecli) 에서 OS별 설치 파일 실행
- 설치 후 새 터미널에서 확인:
  ```bash
  sf --version
  ```
 <img width="1115" height="197" alt="image" src="https://github.com/user-attachments/assets/dbccff63-7ef7-4483-87d5-fa579bdedb0a" />


## 2) VS Code 익스텐션 설치
- VS Code > Extensions (`Ctrl+Shift+X`) > **"Salesforce Extension Pack"** 검색 > **Install**
- 설치 후 VS Code 재시작(권장)

## 3) 프로젝트 clone & 열기
```bash
git clone https://github.com/paulyu8868/dc-ingestion-delete-flow.git
```

- **VS Code에서 dc-ingestion-delete-flow 폴더 직접 Open** (sfdx-project.json 파일을 인식해야 SFDX 커맨드 활성화 됨)

## 4) org 인증 (1회)
- Command Palette (`Ctrl+Shift+P`) > **SFDX: Authorize an Org**
- **Login URL 선택** (production 기준):
  - `Production` (`https://login.salesforce.com`), 또는
  - My Domain 사용 시 `Custom` > `https://<mydomain>.my.salesforce.com`
- 브라우저 로그인 > **허용**
- (선택) Command Palette > **SFDX: Set a Default Org** 로 방금 org 를 기본값 지정

## 5) 배포 (Production)
Production 은 배포 시 **테스트 실행 + 커버리지 75%** 가 강제된다.
우클릭 "Deploy Source to Org" 는 기본 `NoTestRun` 이라 production 에선 거부되므로 **CLI 로 test level 을 지정**한다.

- (sandbox/scratch) Explorer 에서 **`force-app`** 폴더 우클릭 > **SFDX: Deploy Source to Org**
 <img width="596" height="940" alt="image" src="https://github.com/user-attachments/assets/038a5123-7e2d-4cd7-8423-43744bf0c1ed" />

- (production) CLI 로 배포:
```bash
# (권장) 1. 검증만 — 실제 반영 없이 테스트/커버리지 확인
sf project deploy start -d force-app -o prod --dry-run -l RunLocalTests
# 2. 통과하면 실제 반영 (재테스트 없이 빠르게)
sf project deploy quick --use-most-recent -o prod

# 또는 한 번에: 배포+테스트
sf project deploy start -d force-app -o prod -l RunLocalTests
```

## 6) 확인 & 커버리지
- Setup > **Apex Classes** 에 `DataCloudIngestDelete`, `DataCloudAuthProvider` 존재
 <img width="1920" height="1032" alt="image" src="https://github.com/user-attachments/assets/03d2dc81-2ecc-4beb-84a1-a6d5341b0c4c" />
- Production 배포(`RunLocalTests`)면 **배포 과정에서 테스트가 실행되어 커버리지가 검증**된다.
- 커버리지를 따로 확인하려면:
```bash
sf apex run test -o prod --tests DataCloudAuthProviderTest --tests DataCloudIngestDeleteTest \
  --code-coverage --result-format human --wait 10
```
<img width="1920" height="721" alt="image" src="https://github.com/user-attachments/assets/0deaa856-36a7-4bb1-8bff-eb85bc514baa" />


---

## 참고
- `DataCloudIngestDelete` 는 source/object/NamedCredential 을 **필수 인자**로 받는다(하드코딩 없음).
  대상 지정은 Flow(06) 몫.
- sf CLI 를 쓸 수 없는 환경이면 repo 루트의 `deploy_apex.py`(자체 사용법 주석 포함)로도 배포할 수 있다.

관련: [개념 §4](concept.md) · 다음 → [03-auth-provider](03-auth-provider.md)
