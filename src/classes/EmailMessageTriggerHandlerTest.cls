@isTest
public class EmailMessageTriggerHandlerTest {
     @isTest
    static void testCreateCaseTeamMember() {
        //Insert test case record
        Case caseRec = new Case();
        caseRec.Subject = 'OK Test';  
        caseRec.Status ='New';
        caseRec.Priority = 'Medium';
        caseRec.Origin = 'Email';
        insert caseRec;

        for(Integer i =0;i<20;i++){
            //Insert emailmessage for case
            EmailMessage emailRec = new EmailMessage();
            emailRec.FromAddress = 'test@abc.org';
            emailRec.Incoming = True;
            emailRec.ToAddress= 'test@xyz.org';
            emailRec.ccAddress= 'sf.sonal@gmail.com; test@gmail.com';
            emailRec.Subject = 'Test email';
            emailRec.HtmlBody = 'Test email body';
            emailRec.ParentId = caseRec.Id; 
            insert emailRec;
        }
        

        //Assert if case Description_HTML__c updated with emailmessage htmlbody value
        System.assertEquals([Select Id, Subject From Case Where Id = :caseRec.Id][0].Subject,
                            'OK Test');
    }
	
}