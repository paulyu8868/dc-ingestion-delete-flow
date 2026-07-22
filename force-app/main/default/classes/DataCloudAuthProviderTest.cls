/**
 * DataCloudAuthProvider 테스트. 토큰 콜아웃(core→a360)을 순차 목으로 대체.
 */
@IsTest
private class DataCloudAuthProviderTest {

    private class SeqMock implements HttpCalloutMock {
        private List<HttpResponse> responses;
        private Integer idx = 0;
        SeqMock(List<HttpResponse> r) { this.responses = r; }
        public HttpResponse respond(HttpRequest req) {
            return responses[Math.min(idx++, responses.size() - 1)];
        }
    }

    private static HttpResponse json(Integer code, String body) {
        HttpResponse r = new HttpResponse();
        r.setStatusCode(code);
        r.setHeader('Content-Type', 'application/json');
        r.setBody(body);
        return r;
    }

    private static Map<String, String> cfg() {
        return new Map<String, String>{
            'Token_Endpoint__c' => 'https://core.develop.my.salesforce.com/services/oauth2/token',
            'Client_Id__c'      => 'CID',
            'Client_Secret__c'  => 'CSECRET',
            'Callback_URL__c'   => 'https://login.salesforce.com/services/authcallback/DataCloud'
        };
    }

    private static SeqMock happyMock() {
        return new SeqMock(new List<HttpResponse>{
            json(200, '{"access_token":"CORE","instance_url":"https://core.develop.my.salesforce.com"}'),
            json(200, '{"access_token":"A360","instance_url":"https://dc.c360a.salesforce.com"}')
        });
    }

    @IsTest
    static void initiateRedirects() {
        DataCloudAuthProvider p = new DataCloudAuthProvider();
        PageReference pr = p.initiate(cfg(), 'STATE123');
        System.assert(pr.getUrl().contains('STATE123'), 'state 전파 확인');
    }

    @IsTest
    static void handleCallbackReturnsToken() {
        Test.setMock(HttpCalloutMock.class, happyMock());
        DataCloudAuthProvider p = new DataCloudAuthProvider();
        Auth.AuthProviderCallbackState st = new Auth.AuthProviderCallbackState(
            new Map<String, String>(), '', new Map<String, String>{ 'state' => 'S' });
        Test.startTest();
        Auth.AuthProviderTokenResponse resp = p.handleCallback(cfg(), st);
        Test.stopTest();
        System.assertEquals('A360', resp.oauthToken, 'a360 토큰 반환');
    }

    @IsTest
    static void refreshReturnsToken() {
        Test.setMock(HttpCalloutMock.class, happyMock());
        DataCloudAuthProvider p = new DataCloudAuthProvider();
        Test.startTest();
        Auth.OAuthRefreshResult rr = p.refresh(cfg(), 'noRefresh');
        Test.stopTest();
        System.assertEquals('A360', rr.accessToken);
    }

    @IsTest
    static void getUserInfoWorks() {
        DataCloudAuthProvider p = new DataCloudAuthProvider();
        Auth.UserData ud = p.getUserInfo(cfg(),
            new Auth.AuthProviderTokenResponse('DataCloudAuthProvider', 'A360', 'noRefresh', 'S'));
        System.assertEquals('DataCloudAuthProvider', ud.provider);
    }

    @IsTest
    static void coreTokenErrorThrows() {
        Test.setMock(HttpCalloutMock.class, new SeqMock(new List<HttpResponse>{
            json(400, '{"error":"invalid_client"}')
        }));
        DataCloudAuthProvider p = new DataCloudAuthProvider();
        Boolean threw = false;
        Test.startTest();
        try {
            p.fetchDcToken(cfg());
        } catch (DataCloudAuthProvider.ProviderException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'core token 실패 시 예외');
    }
}
