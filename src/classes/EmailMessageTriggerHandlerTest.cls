@isTest
public class EmailMessageTriggerHandlerTest {
    
    @IsTest
    static void testEmailSplitter () {
        System.assertEquals(
            // try semicolon with spaces and without
	        EmailMessageTriggerHandler.splitEmailList('test1@example.com;test2@example.com ; test3@example.com'),
            new Set<String>{'test1@example.com', 'test2@example.com', 'test3@example.com'},
            'parse did not get desired emails'
        );
    }
    
    @IsTest
    static void testNoLinkToCase () {
        // should not throw exception
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{'test@example.com'});
        mail.setCcAddresses(new List<String>{UserInfo.getUserEmail()});
		mail.setSubject('Test Subject');
        mail.setPlainTextBody('Test Body');
        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        } catch (Exception e) {
            System.assert(false, 'exception thrown: ' + e);
        }
    }
    
    @IsTest
    static void testFindAddressesFromEmails () {
        System.assert(
            EmailMessageTriggerHandler.getEmailsByParentId(
                new List<EmailMessage>{
                    new EmailMessage(
                        FromAddress = 'customer@example.com',
                        ToAddress = 'email-to-case@example.com',
                        Subject = 'Test Subject',
                        HtmlBody = 'Test email body'
                    )
                }
            ).keySet().isEmpty(),
            'should not have found any emails'
        );
        
        System.assert(
            EmailMessageTriggerHandler.getEmailsByParentId(
                new List<EmailMessage>{
                    new EmailMessage(
                        FromAddress = 'customer@example.com',
                        ToAddress = 'email-to-case@example.com',
                        CcAddress = 'test@example.com ; ' + UserInfo.getUserEmail(),
                        Subject = 'Test Subject',
                        HtmlBody = 'Test email body',
                        ParentId = '500000000000001' // NOPMD
                    )
                }
            ).keySet().isEmpty() != true,
            'should have found one user'
        );
    }

    @IsTest
    static void integrationTest () {
                
        Case testCase = new Case(
            Subject = 'OK Test'
        );
        insert testCase;

        Integer caseTeamCount = [select Id from CaseTeamMember where ParentId = :testCase.Id].size();

        // given no new internal user emails added
        // should not raise exception
		
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setWhatId(testCase.Id);
        mail.setToAddresses(new List<String>{'test@example.com'});
		mail.setSubject('Test Subject');
        mail.setPlainTextBody('Test Body');
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        
        System.assertEquals(1, [select Id from EmailMessage where ParentId = :testCase.Id].size(), 'email was not logged');
        
        // no new case team members should be added
        System.assertEquals(caseTeamCount, [select Id from CaseTeamMember where ParentId = :testCase.Id].size(), 'case count should not have changed');
        
        // when i am cc'd on a case, i should be added to case team
        mail = new Messaging.SingleEmailMessage();
        mail.setWhatId(testCase.Id);
        mail.setToAddresses(new List<String>{'test@example.com'});
        mail.setCcAddresses(new List<String>{UserInfo.getUserEmail()});
		mail.setSubject('Test Subject');
        mail.setPlainTextBody('Test Body');
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        
        // we should be on case team
        System.assertEquals(caseTeamCount + 1, [select Id from CaseTeamMember where MemberId = :UserInfo.getUserId() and ParentId = :testCase.Id].size(), 'case team should have grown by one');

        // getting cc'd a second time should NOT raise exception
        mail = new Messaging.SingleEmailMessage();
        mail.setWhatId(testCase.Id);
        mail.setToAddresses(new List<String>{'test@example.com'});
        mail.setCcAddresses(new List<String>{UserInfo.getUserEmail()});
		mail.setSubject('Test Subject');
        mail.setPlainTextBody('Test Body');
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        
        // and it should be the same number of members
        System.assertEquals(caseTeamCount + 1, [select Id from CaseTeamMember where MemberId = :UserInfo.getUserId() and ParentId = :testCase.Id].size(), 'member not added to case');

    }
	
}