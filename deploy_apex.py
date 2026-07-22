"""
apex/ 폴더(소스포맷)를 Metadata API(SOAP)로 배포. sf CLI 불필요.
- 인증: salesforce-cli(데이터클라우드)/.env 의 client_credentials 토큰을 sessionId 로 사용
        (flipper 배포에 검증된 자격 — Metadata 배포 권한 확인됨)
- Phase 1: CMDT 타입 + Apex 클래스 (RunSpecifiedTests)
- Phase 2: CMDT 레코드 (타입 커밋 후)
- 소스포맷 objects/*/ (object-meta + fields/*) → MDAPI 단일 .object 로 변환

사용:
  python deploy_apex.py            # Phase1 checkOnly 검증만 (org 변경 없음)
  python deploy_apex.py --deploy   # 실제 배포
"""
import argparse, base64, io, os, re, sys, time, zipfile
import xml.etree.ElementTree as ET
import requests
from dotenv import load_dotenv

MD_API = "62.0"
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "force-app", "main", "default")   # SFDX 표준 소스 경로
# 배포 자격 .env: 환경변수 SF_DEPLOY_ENV 로 지정하거나, 스크립트 옆의 .env (gitignore 됨).
# 필요한 키: SF_LOGIN_URL, SF_CLIENT_ID, SF_CLIENT_SECRET (+ 선택 SF_USERNAME, SF_PASSWORD_AND_TOKEN)
DEPLOY_ENV = os.environ.get("SF_DEPLOY_ENV") or os.path.join(HERE, ".env")

NS = "http://soap.sforce.com/2006/04/metadata"
CLASSES = ["DataCloudAuthProvider", "DataCloudAuthProviderTest",
           "DataCloudIngestDelete", "DataCloudIngestDeleteTest"]
OBJECTS = ["DataCloud_Auth_Provider__mdt"]
TESTS = ["DataCloudAuthProviderTest", "DataCloudIngestDeleteTest"]
# CMDT 레코드는 배포 안 함. (Auth_Provider 설정값은 Auth Provider 등록 화면에서 입력)
RECORDS = []


def core_token():
    load_dotenv(DEPLOY_ENV)
    lu = os.environ["SF_LOGIN_URL"].rstrip("/")
    cid = os.environ["SF_CLIENT_ID"]; cs = os.environ["SF_CLIENT_SECRET"]
    un = os.environ.get("SF_USERNAME"); pw = os.environ.get("SF_PASSWORD_AND_TOKEN")
    data = ({"grant_type": "password", "client_id": cid, "client_secret": cs,
             "username": un, "password": pw} if (un and pw)
            else {"grant_type": "client_credentials", "client_id": cid, "client_secret": cs})
    r = requests.post(f"{lu}/services/oauth2/token", data=data); r.raise_for_status()
    j = r.json(); return j["access_token"], j["instance_url"]


def readf(*p):
    with open(os.path.join(SRC, *p), encoding="utf-8") as f:
        return f.read()


def build_object_mdapi(obj_name):
    """소스포맷 objects/<obj>/ → MDAPI 단일 .object 문자열."""
    base = os.path.join(SRC, "objects", obj_name)
    ET.register_namespace("", NS)
    meta = ET.parse(os.path.join(base, obj_name + ".object-meta.xml")).getroot()
    def g(tag):
        e = meta.find("{%s}%s" % (NS, tag)); return e.text if e is not None else None
    label = g("label") or obj_name
    plural = g("pluralLabel") or label
    vis = g("visibility") or "Public"

    fields_xml = ""
    fdir = os.path.join(base, "fields")
    for fn in sorted(os.listdir(fdir)):
        fr = ET.parse(os.path.join(fdir, fn)).getroot()
        def fg(tag):
            e = fr.find("{%s}%s" % (NS, tag)); return e.text if e is not None else None
        full = fg("fullName"); flabel = fg("label") or full
        length = fg("length") or "255"; ftype = fg("type") or "Text"
        req = (fg("required") or "false")
        fields_xml += f"""    <fields>
        <fullName>{full}</fullName>
        <fieldManageability>DeveloperControlled</fieldManageability>
        <label>{flabel}</label>
        <length>{length}</length>
        <required>{req}</required>
        <type>{ftype}</type>
        <unique>false</unique>
    </fields>
"""
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="{NS}">
    <label>{label}</label>
    <pluralLabel>{plural}</pluralLabel>
    <visibility>{vis}</visibility>
{fields_xml}</CustomObject>
"""


def zip_b64(package_xml, files):
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("package.xml", package_xml)
        for path, content in files:
            z.writestr(path, content)
    return base64.b64encode(buf.getvalue()).decode()


def soap(instance_url, token, body_inner):
    envelope = f"""<?xml version="1.0" encoding="UTF-8"?>
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:met="{NS}">
  <soapenv:Header><met:SessionHeader><met:sessionId>{token}</met:sessionId></met:SessionHeader></soapenv:Header>
  <soapenv:Body>{body_inner}</soapenv:Body>
</soapenv:Envelope>"""
    return requests.post(f"{instance_url}/services/Soap/m/{MD_API}",
                         data=envelope.encode("utf-8"),
                         headers={"Content-Type": "text/xml; charset=UTF-8", "SOAPAction": '""'})


def run_deploy(instance_url, token, z_b64, check_only, test_level, run_tests=None):
    rt = "".join(f"<met:runTests>{t}</met:runTests>" for t in (run_tests or []))
    body = f"""<met:deploy>
      <met:ZipFile>{z_b64}</met:ZipFile>
      <met:DeployOptions>
        <met:rollbackOnError>true</met:rollbackOnError>
        <met:testLevel>{test_level}</met:testLevel>{rt}
        <met:checkOnly>{'true' if check_only else 'false'}</met:checkOnly>
        <met:singlePackage>true</met:singlePackage>
      </met:DeployOptions>
    </met:deploy>"""
    r = soap(instance_url, token, body)
    if not r.ok:
        print("deploy 요청 실패:", r.status_code, r.text[:1000]); return False
    m = re.search(r"<id>(.*?)</id>", r.text)
    if not m:
        print("deploy id 파싱 실패:", r.text[:1200]); return False
    async_id = m.group(1); print("  deploy id:", async_id)
    for _ in range(60):
        time.sleep(5)
        s = soap(instance_url, token,
                 f"<met:checkDeployStatus><met:asyncProcessId>{async_id}</met:asyncProcessId>"
                 f"<met:includeDetails>true</met:includeDetails></met:checkDeployStatus>")
        if not re.search(r"<done>true</done>", s.text):
            continue
        st = re.search(r"<status>(.*?)</status>", s.text)
        st = st.group(1) if st else "?"
        ok = st in ("Succeeded", "SucceededPartial")
        print("  status:", st, "OK" if ok else "FAIL")
        em = re.search(r"<errorMessage>(.*?)</errorMessage>", s.text, re.S)
        if em: print("  errorMessage:", em.group(1))
        for fm in re.finditer(r"<componentFailures>(.*?)</componentFailures>", s.text, re.S):
            b = fm.group(1)
            fn = re.search(r"<fullName>(.*?)</fullName>", b); pr = re.search(r"<problem>(.*?)</problem>", b)
            print("   - FAIL", fn and fn.group(1), ":", pr and pr.group(1))
        for fm in re.finditer(r"<failures>(.*?)</failures>", s.text, re.S):
            b = fm.group(1)
            nm = re.search(r"<methodName>(.*?)</methodName>", b); msg = re.search(r"<message>(.*?)</message>", b)
            print("   - TEST FAIL", nm and nm.group(1), ":", msg and msg.group(1))
        return ok
    print("  폴링 타임아웃"); return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--deploy", action="store_true")
    args = ap.parse_args()

    token, instance_url = core_token()
    print(f"instance_url = {instance_url}\n")

    pkg1 = f"""<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="{NS}">
    <types>{''.join(f'<members>{c}</members>' for c in CLASSES)}<name>ApexClass</name></types>
    <types>{''.join(f'<members>{o}</members>' for o in OBJECTS)}<name>CustomObject</name></types>
    <version>{MD_API}</version>
</Package>"""
    files1 = []
    for o in OBJECTS:
        files1.append((f"objects/{o}.object", build_object_mdapi(o)))
    for c in CLASSES:
        files1.append((f"classes/{c}.cls", readf("classes", c + ".cls")))
        files1.append((f"classes/{c}.cls-meta.xml", readf("classes", c + ".cls-meta.xml")))
    z1 = zip_b64(pkg1, files1)

    check = not args.deploy
    print(f"[Phase 1] {'checkOnly 검증' if check else '실제 배포'} (CMDT 타입 + 클래스, RunSpecifiedTests)")
    if not run_deploy(instance_url, token, z1, check, "RunSpecifiedTests", TESTS):
        print("Phase 1 실패 → 중단"); sys.exit(1)
    if check:
        print("\n검증 통과. 실제 배포하려면: python deploy_apex.py --deploy"); return

    if not RECORDS:
        print("\n배포 완료 (CMDT 레코드 없음). 다음: Auth Provider 등록 → Remote Site → Named Credential (AUTH_SETUP.md)")
        return

    pkg2 = f"""<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="{NS}">
    <types>{''.join(f'<members>{r}</members>' for r in RECORDS)}<name>CustomMetadata</name></types>
    <version>{MD_API}</version>
</Package>"""
    files2 = [(f"customMetadata/{r}.md", readf("customMetadata", r + ".md-meta.xml")) for r in RECORDS]
    z2 = zip_b64(pkg2, files2)
    print("\n[Phase 2] CMDT 레코드 배포")
    if not run_deploy(instance_url, token, z2, False, "NoTestRun"):
        print("Phase 2 실패"); sys.exit(1)
    print("\n배포 완료. 다음: Auth Provider 등록 → Remote Site → Named Credential (README)")


if __name__ == "__main__":
    main()
