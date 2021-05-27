public with sharing class EmailMessageTriggerHandler {
    
    private static final ROLE_NAME = 'Collaborator';

    private static Set<String> splitEmailList (String s) {
        Set<String> emails = new Set<String>();
        if (String.isNotBlank(s)) {
            for (String email : s.split(';')) {
                emails.add(s.trim().toLowerCase());
            }
        }
        return emails;
    }
    
    public static void createCaseTeamMember(List<EmailMessage> newEmailMessageList){
        Map<Id, Set<String>> mapCaseIdWithAddresses = new Map<Id, Set<String>>();
        Set<String> foundEmailAddresses = new Set<String>();
        for(EmailMessage  emailMsg : newEmailMessageList){
            if (emailMsg.ParentId == null || emailMsg.ParentId.getSObjectType() != Schema.Case.SObjectType) continue;
            Set<String> emailsFound = splitEmailList(emailMsg.ToAddresses);
            emailsFound.addAll(splitEmailList(emailMsg.CcAddresses));
            emailsFound.addAll(splitEmailList(emailMsg.BccAddresses));
            if (emailsFound.isEmpty()) continue;
            if(!mapCaseIdWithAddresses.containsKey(emailMsg.ParentId)){
                mapCaseIdWithAddresses.put(emailMsg.ParentId, new Set<String>());
            }
            mapCaseIdWithAddresses.get(emailMsg.ParentId).addAll(emailsFound);
            foundEmailAddresses.addAll(emailMsg.CcAddress.toLowerCase().split('; '));
        }
                
        Map<String, Id> mapEmailWithUserId = new Map<String, Id>();
        for(User userRec : [SELECT ID, Email, Profile.UserLicense.Name FROM USER WHERE isActive = true AND Email IN: foundEmailAddresses AND Profile.UserLicense.Name = 'Salesforce' LIMIT 10000]){
            mapEmailWithUserId.put(userRec.Email.toLowerCase(),userRec.Id);
        }
        
        List<CaseTeamRole> caseTeamRoleList = [SELECT Id FROM CaseTeamRole WHERE Name = :ROLE_NAME LIMIT 1];
        
        // fail over to first team role if we couldn't find our normal one
        if (caseTeamRoleList.isEmpty()) caseTeamRoleList = [SELECT Id FROM CaseTeamRole LIMIT 1];

        List<CaseTeamMember> caseTeamMemberList = new List<CaseTeamMember>();
       
        if(caseTeamRoleList.size()>0){
            for(Id caseId : mapCaseIdWithCCAddresses.keySet()){
                for(String email : mapCaseIdWithCCAddresses.get(caseId)){
                    if(mapEmailWithUserId.containsKey(email.toLowerCase())){
                         System.debug('userRec.Id::'+email.toLowerCase());
                        System.debug('userRec.Id::'+mapEmailWithUserId.get(email.toLowerCase()));
                        CaseTeamMember caseTeamMemberRec =new CaseTeamMember();
                        caseTeamMemberRec.ParentId= caseId;
                        caseTeamMemberRec.MemberId= mapEmailWithUserId.get(email.toLowerCase());
                        caseTeamMemberRec.TeamRoleId = caseTeamRoleList[0].id;
                        caseTeamMemberList.add(caseTeamMemberRec);
                    }
                }
            }
        }
        
        
      Database.saveResult[] saveResultList = Database.insert(caseTeamMemberList,false);
        for(Database.saveResult saveResult : saveResultList){
            if(!saveResult.isSuccess()){
                for(Database.Error error : saveResult.getErrors()){
                    System.debug('Error Occured:::'+error.getMessage()+' :: '+error.getStatusCode()+' :: '+error.getFields() );
                }
            }
        }
       
    }
    
    
}