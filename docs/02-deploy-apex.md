# 02. Apex 배포

> 삭제 로직(`DataCloudIngestDelete`)과 토큰 교환(`DataCloudAuthProvider`), Auth Provider 설정 저장용
> CMDT(`DataCloud_Auth_Provider__mdt`)를 org 에 배포한다. Auth Provider 등록에는 `DataCloudAuthProvider` 클래스 배포가 선행되어야함.

이 repo 는 표준 SFDX 프로젝트다(`sfdx-project.json` + `force-app/main/default/`). 소스:
```
force-app/main/default/classes/DataCloudIngestDelete.cls   (+ Test)   Invocable 삭제
force-app/main/default/classes/DataCloudAuthProvider.cls   (+ Test)   core→a360 토큰 교환
force-app/main/default/objects/DataCloud_Auth_Provider__mdt/          Auth Provider 설정 CMDT
```

## 방법 A — VS Code / sf CLI (정석)
1. **org 인증** (1회): VS Code `SFDX: Authorize an Org`, 또는
   ```bash
   sf org login web -a <alias>
   ```
2. **배포**: VS Code 에서 `force-app` 우클릭 > **SFDX: Deploy Source to Org**, 또는
   ```bash
   sf project deploy start -d force-app -o <alias> -l RunSpecifiedTests
   ```
> clone → org 인증(브라우저 1회) → Deploy 로 코드 배포가 끝난다. (org 설정은 03~06 별도)
> 📷 [스크린샷] Deploy Source to Org 결과

## 방법 B — 포함된 스크립트 (sf CLI 없는 환경용 fallback)
`deploy_apex.py` = Metadata API(SOAP) 배포. 배포 자격 `.env` 를 `SF_DEPLOY_ENV` 로 지정하거나
스크립트 옆 `.env`(gitignore) 에 둔다. 필요한 키: `SF_LOGIN_URL`, `SF_CLIENT_ID`, `SF_CLIENT_SECRET`.
```bash
python deploy_apex.py            # checkOnly 검증 (org 변경 없음)
python deploy_apex.py --deploy   # 실제 배포
```

## 확인
- Setup > **Apex Classes** 에 `DataCloudIngestDelete`, `DataCloudAuthProvider` 존재
- 테스트가 함께 통과(RunSpecifiedTests)

## 참고
- `DataCloudIngestDelete` 는 source/object/NamedCredential 을 **필수 인자**로 받는다(하드코딩 없음).
  대상 지정은 Flow(06) 몫.

관련: [개념 §4](concept.md) · 다음 → [03-auth-provider](03-auth-provider.md)
