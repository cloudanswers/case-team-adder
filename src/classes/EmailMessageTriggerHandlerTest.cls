@isTest
public class EmailMessageTriggerHandlerTest {

    @IsTest
    static void testNoLinkToCase () {
        // should not throw exception
        insert new EmailMessage(
            FromAddress = 'customer@example.com',
            ToAddress = 'email-to-case@example.com',
            Subject = 'Test Subject',
            HtmlBody = 'Test email body',
        );
    }

    @isTest
    static void testCreateCaseTeamMember() {
        Case testCase = new Case(
            Subject = 'OK Test'
        );
        insert testCase;

        Integer caseTeamCount = [select Id from CaseTeamMember where ParentId = testCase.Id].size();

        // given no new internal user emails added
        // should not raise exception

        insert new EmailMessage(
            FromAddress = 'customer@example.com',
            ToAddress = 'email-to-case@example.com',
            Subject = 'Test Subject',
            HtmlBody = 'Test email body',
            ParentId = testCase.Id
        );

        // no new case team members should be added
        System.assertEquals(caseTeamCount, [select Id from CaseTeamMember where ParentId = testCase.Id].size());
        
        // given i am cc'd on a case, i should be added to case team

        insert new EmailMessage(
            FromAddress = 'customer@example.com',
            ToAddress = 'email-to-case@example.com',
            Subject = 'Test Subject',
            HtmlBody = 'Test email body',
            ParentId = testCase.Id
        );

        // we should be on case team
        System.assertEquals(1, [select Id from CaseTeamMember where MemberId = UserInfo.getUserId() and ParentId = :testCase.Id].size());

        // getting cc'd a second time should NOT raise exception
        
        insert new EmailMessage(
            FromAddress = 'customer@example.com',
            ToAddress = 'email-to-case@example.com',
            Subject = 'Test Subject',
            HtmlBody = 'Test email body',
            ParentId = testCase.Id
        );
        
    }
	
}