/**
 * Data Cloud 용 커스텀 Auth Provider.
 *
 * Named Credential 이 이 provider 를 통해 **a360 DC 토큰**을 자동 발급/주입한다.
 * 흐름(이 org 검증 방식): client_credentials → core token → a360 교환 → DC access token.
 *   ※ JWT bearer 는 이 org 에서 막힘 → 사용 금지.
 *
 * 설정: DataCloud_Auth_Provider__mdt (Auth Provider 등록 화면에서 값 입력, CMDT 로 저장).
 *   Token_Endpoint__c : https://<org>.develop.my.salesforce.com/services/oauth2/token
 *   Client_Id__c      : Connected App(client_credentials) client id
 *   Client_Secret__c  : 〃 secret  ← 시크릿은 이 Auth Provider 설정에만 존재(비즈니스 코드 미노출)
 *   Callback_URL__c   : Auth Provider 등록 후 생성되는 Callback URL 을 복사해 넣음
 *
 * ⚠️ Auth Provider 자체 콜아웃(코어 토큰/a360)은 **코어 도메인 Remote Site Setting** 필요.
 *    (DC 호스트 콜아웃은 Named Credential 이 담당 → Remote Site 불필요)
 */
global class DataCloudAuthProvider extends Auth.AuthProviderPluginClass {

    public class ProviderException extends Exception {}

    private static final String PROVIDER_NAME = 'DataCloudAuthProvider';

    global String getCustomMetadataType() {
        return 'DataCloud_Auth_Provider__mdt';
    }

    /** 사용자 상호작용 없이 즉시 콜백으로 리다이렉트 (비대화형 토큰 발급 트릭). */
    global PageReference initiate(Map<String, String> config, String stateToPropagate) {
        String url = config.get('Callback_URL__c') + '?state=' + stateToPropagate;
        return new PageReference(url);
    }

    /** 콜백에서 실제 토큰 취득. */
    global Auth.AuthProviderTokenResponse handleCallback(Map<String, String> config,
                                                         Auth.AuthProviderCallbackState cbState) {
        String dcToken = fetchDcToken(config);
        String state = (cbState != null && cbState.queryParameters != null)
            ? cbState.queryParameters.get('state') : null;
        // refresh token 개념이 없어 항상 재발급 → 자리표시자
        return new Auth.AuthProviderTokenResponse(PROVIDER_NAME, dcToken, 'noRefresh', state);
    }

    /** NC 콜아웃이 401 받으면 호출됨 → 재발급. */
    global override Auth.OAuthRefreshResult refresh(Map<String, String> config, String refreshToken) {
        String dcToken = fetchDcToken(config);
        return new Auth.OAuthRefreshResult(dcToken, 'noRefresh');
    }

    global Auth.UserData getUserInfo(Map<String, String> config,
                                     Auth.AuthProviderTokenResponse response) {
        return new Auth.UserData(
            'datacloud',            // identifier
            null, null, null,       // first/last/full name
            null, null,             // email, link
            'datacloud',            // userName
            null,                   // locale
            PROVIDER_NAME,          // provider
            null,                   // siteLoginUrl
            new Map<String, String>()
        );
    }

    /** client_credentials → core token → a360 교환 → DC access token. */
    @TestVisible
    private String fetchDcToken(Map<String, String> config) {
        // 1) core token
        HttpRequest r1 = new HttpRequest();
        r1.setEndpoint(config.get('Token_Endpoint__c'));
        r1.setMethod('POST');
        r1.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        r1.setTimeout(120000);
        r1.setBody('grant_type=client_credentials'
            + '&client_id='     + enc(config.get('Client_Id__c'))
            + '&client_secret=' + enc(config.get('Client_Secret__c')));
        HttpResponse resp1 = new Http().send(r1);
        if (resp1.getStatusCode() != 200) {
            throw new ProviderException('core token 실패: ' + resp1.getStatusCode() + ' ' + resp1.getBody());
        }
        Map<String, Object> j1 = (Map<String, Object>) JSON.deserializeUntyped(resp1.getBody());
        String coreToken = (String) j1.get('access_token');
        String instance  = (String) j1.get('instance_url');

        // 2) a360 교환
        HttpRequest r2 = new HttpRequest();
        r2.setEndpoint(instance + '/services/a360/token');
        r2.setMethod('POST');
        r2.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        r2.setTimeout(120000);
        r2.setBody('grant_type=' + enc('urn:salesforce:grant-type:external:cdp')
            + '&subject_token='      + enc(coreToken)
            + '&subject_token_type=' + enc('urn:ietf:params:oauth:token-type:access_token'));
        HttpResponse resp2 = new Http().send(r2);
        if (resp2.getStatusCode() != 200) {
            throw new ProviderException('a360 교환 실패: ' + resp2.getStatusCode() + ' ' + resp2.getBody());
        }
        Map<String, Object> j2 = (Map<String, Object>) JSON.deserializeUntyped(resp2.getBody());
        return (String) j2.get('access_token');
    }

    private static String enc(String v) {
        return EncodingUtil.urlEncode(v, 'UTF-8');
    }
}
